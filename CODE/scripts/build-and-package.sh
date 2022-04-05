set -eu

workspace="$(pwd)"

for arg in "$@"
do
executable=$arg

echo "---------------------------------------"
echo "preparing docker build image"
echo "---------------------------------------"
sudo docker build . -t builder
echo "done"


echo "---------------------------------------"
echo "building \"$executable\" lambda in workspace $workspace"
echo "---------------------------------------"
sudo docker run --rm -v "$workspace":/workspace -w /workspace builder \
    bash -cl "swift build --product $executable -c release -Xswiftc -static-stdlib"
echo "done"


echo "---------------------------------------"
echo "packaging \"$executable\" lambda"
echo "---------------------------------------"
sudo docker run --rm -v "$workspace":/workspace -w /workspace builder \
    bash -cl "./scripts/package.sh $executable"
echo "done" 

done