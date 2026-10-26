#!/usr/bin/bash
# Fetch the Hy-MT2 GGUF model used by llama-server into /var/lib/llama.cpp.
#
# The model is machine-local data (~1.1 GB), not image content: it is kept out
# of the container image and downloaded once on first start. The 1.25bit/2bit
# variants need unmerged llama.cpp kernels (ggml-org/llama.cpp PR #22836 and
# PR #19357), so the stock llama.cpp:server image can only load the standard
# quants.
set -euo pipefail

dir=/var/lib/llama.cpp
model=Hy-MT2-1.8B-Q4_K_M.gguf
url="https://huggingface.co/tencent/Hy-MT2-1.8B-GGUF/resolve/main/${model}"

# Already downloaded: nothing to do, keep the oneshot succeeding so that
# llama-server.service (Requires= this unit) still starts.
if [ -s "$dir/$model" ]; then
    exit 0
fi

mkdir -p "$dir"
tmp="$dir/.${model}.part"
curl -fsSL --retry 5 --retry-delay 5 --retry-all-errors -o "$tmp" "$url"
chmod 0444 "$tmp"
mv "$tmp" "$dir/$model"
