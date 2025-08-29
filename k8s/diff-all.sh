#!/bin/zsh

for i in ./*/*/helmfile.yaml; do helmfile -q -f "$i" diff; done



