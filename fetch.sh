R=suporteafim/afim-prints; H="User-Agent: afim"
for i in $(seq 1 110); do
  S=$(curl -s -H "$H" https://api.github.com/repos/$R/actions/runs | python3 -c "import json,sys;d=json.load(sys.stdin);print(' '.join(r['status'] for r in d['workflow_runs'][:2]))")
  case "$S" in *queued*|*in_progress*|*waiting*) sleep 10;; *) break;; esac
done
curl -s -H "$H" https://api.github.com/repos/$R/actions/runs | python3 -c "import json,sys;[print(r['id'],r['name'],r['status'],r['conclusion']) for r in json.load(sys.stdin)['workflow_runs'][:2]]"
mkdir -p out; cd out
curl -s -H "$H" https://api.github.com/repos/$R/actions/artifacts | python3 -c "import json,sys;[print(a['name'],a['archive_download_url']) for a in json.load(sys.stdin)['artifacts']]" | while read n u; do curl -sL -H "$H" -o $n.zip "$u"; unzip -oq $n.zip -d $n; done
find . -type f | grep -v zip
