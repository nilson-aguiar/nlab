#!/bin/zsh

for i in ./*/overlay; do cd "$i" || continue ; kubectl apply -k .; cd - || exit; done

for i in ./*/helmfile.yaml; do helmfile -f "$i" apply; done



