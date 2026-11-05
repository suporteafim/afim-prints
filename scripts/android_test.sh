#!/bin/bash
set +e
mkdir -p shots
adb root || true ; sleep 3 ; adb wait-for-device ; sleep 2
adb shell setprop persist.sys.timezone America/Sao_Paulo || true
adb shell settings put global auto_time_zone 0 || true
adb shell settings put system system_locales pt-BR || true
adb shell setprop persist.sys.locale pt-BR || true
adb shell settings put global hide_error_dialogs 1 || true
# reinicia o framework para aplicar o idioma pt-BR
adb shell stop || true ; sleep 3 ; adb shell start || true
until [ "$(adb shell getprop sys.boot_completed | tr -d '\r')" = "1" ]; do sleep 3; done
sleep 45  # deixa o launcher assentar (evita 'Pixel Launcher isn't responding')
adb shell input keyevent KEYCODE_HOME ; sleep 5
adb shell settings put system time_12_24 24 || true
# cara de celular pessoal: barra limpa, hora de Brasília, bateria e sinal reais
HORA=$(TZ=America/Sao_Paulo date +%H%M)
adb shell settings put global sysui_demo_allowed 1
adb shell am broadcast -a com.android.systemui.demo -e command enter
adb shell am broadcast -a com.android.systemui.demo -e command clock -e hhmm $HORA
adb shell am broadcast -a com.android.systemui.demo -e command battery -e level 78 -e plugged false
adb shell am broadcast -a com.android.systemui.demo -e command network -e wifi show -e level 4
adb shell am broadcast -a com.android.systemui.demo -e command network -e mobile show -e datatype 4g -e level 4
adb shell am broadcast -a com.android.systemui.demo -e command notifications -e visible false
echo "Hora na barra: $HORA (Brasília)"
# pular a tela de boas-vindas do Chrome
adb shell 'echo "_ --disable-fre --no-default-browser-check --no-first-run" > /data/local/tmp/chrome-command-line'
adb shell am set-debug-app --persistent com.android.chrome
adb shell am start -a android.intent.action.VIEW -d "https://afimguairasp-baixar.static.hf.space/" ; sleep 15
# fecha o aviso de notificações do Chrome, se aparecer
adb shell uiautomator dump /sdcard/ui.xml >/dev/null 2>&1 ; adb pull /sdcard/ui.xml /tmp/ui.xml >/dev/null 2>&1
B=$(python3 -c "
import re,sys
x=open('/tmp/ui.xml',encoding='utf-8').read() if __import__('os').path.exists('/tmp/ui.xml') else ''
for t in ['Não','No thanks','Não, obrigado']:
  m=re.search(r'text=\"'+t+r'\"[^>]*bounds=\"\[(\d+),(\d+)\]\[(\d+),(\d+)\]',x)
  if m:
    a,b,c,d=map(int,m.groups()); print((a+c)//2,(b+d)//2); break
")
[ -n "$B" ] && adb shell input tap $B && sleep 3
adb exec-out screencap -p > shots/a1_pagina_baixar.png
adb install -r afim.apk ; sleep 3
PKG=$(adb shell pm list packages -3 | tr -d '\r' | sed 's/package://' | grep -iv -E "google|android" | head -1) ; echo "pacote $PKG"
adb shell am force-stop com.android.chrome ; adb shell monkey -p $PKG -c android.intent.category.LAUNCHER 1 ; sleep 15 ; adb exec-out screencap -p > shots/a2_app_abertura.png
sleep 8 ; adb exec-out screencap -p > shots/a3_app_tela.png
adb shell input tap 540 1800 ; sleep 5 ; adb exec-out screencap -p > shots/a4_toque_1.png
adb shell input swipe 540 1800 540 600 ; sleep 3 ; adb exec-out screencap -p > shots/a5_rolagem.png
adb shell input keyevent KEYCODE_BACK ; sleep 3 ; adb exec-out screencap -p > shots/a6_voltar.png
adb shell input keyevent KEYCODE_HOME ; sleep 3 ; adb exec-out screencap -p > shots/a7_icone_tela_inicio.png
FOCO=$(adb shell dumpsys window | grep -m1 mCurrentFocus | tr -d '\r')
adb logcat -d > shots/logcat.txt
if grep -q "FATAL EXCEPTION" shots/logcat.txt; then echo "RESULTADO: app FECHOU (crash)" | tee shots/resultado.txt; else echo "RESULTADO: abriu e navegou sem crash" | tee shots/resultado.txt; fi
echo "Pacote: $PKG | Tela em foco no fim: $FOCO" | tee -a shots/resultado.txt
