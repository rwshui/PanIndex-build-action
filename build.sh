ls -n
go env -w GO111MODULE=on
docker pull techknowlogick/xgo:latest
go install src.techknowlogick.com/xgo@latest
go install github.com/gobuffalo/packr/v2@latest
sudo apt install upx
ls -n