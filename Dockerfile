# FROM golang:1.26-bookworm AS builder

# WORKDIR /app

# RUN apt-get update && apt-get install -y --no-install-recommends build-essential git && rm -rf /var/lib/apt/lists/*

# COPY go.mod go.sum ./

# RUN go mod download

# COPY . .

# ARG VERSION=dev
# ARG COMMIT=none
# ARG BUILD_DATE=unknown

# RUN CGO_ENABLED=1 GOOS=linux go build -buildvcs=false -ldflags="-s -w -X 'main.Version=${VERSION}' -X 'main.Commit=${COMMIT}' -X 'main.BuildDate=${BUILD_DATE}'" -o ./CLIProxyAPI ./cmd/server/

# FROM debian:bookworm

# RUN apt-get update && apt-get install -y --no-install-recommends tzdata ca-certificates && rm -rf /var/lib/apt/lists/*

# RUN mkdir /CLIProxyAPI

# COPY --from=builder ./app/CLIProxyAPI /CLIProxyAPI/CLIProxyAPI

# COPY config.example.yaml /CLIProxyAPI/config.example.yaml

# WORKDIR /CLIProxyAPI

# EXPOSE 8317

# ENV TZ=Asia/Shanghai

# RUN cp /usr/share/zoneinfo/${TZ} /etc/localtime && echo "${TZ}" > /etc/timezone

# CMD ["./CLIProxyAPI"]
# ================= 第一阶段：基于 Golang 环境进行源码编译 =================
FROM golang:1.26-bookworm AS builder

WORKDIR /app

RUN apt-get update && apt-get install -y --no-install-recommends build-essential git && rm -rf /var/lib/apt/lists/*

COPY go.mod go.sum ./

RUN go mod download

COPY . .

ARG VERSION=dev
ARG COMMIT=none
ARG BUILD_DATE=unknown

# 编译出可执行文件，输出到当前目录下
RUN CGO_ENABLED=1 GOOS=linux go build -buildvcs=false -ldflags="-s -w -X 'main.Version=${VERSION}' -X 'main.Commit=${COMMIT}' -X 'main.BuildDate=${BUILD_DATE}'" -o ./CLIProxyAPI ./cmd/server/

# ================= 第二阶段：构建极其轻量的最终运行环境 =================
FROM debian:bookworm

RUN apt-get update && apt-get install -y --no-install-recommends tzdata ca-certificates && rm -rf /var/lib/apt/lists/*

# 强行创建项目硬编码报错的绝对路径
RUN mkdir -p /CLIProxyAPI

# 1. 🌟 从第一阶段编译环境里，把刚刚做好的可执行文件复制到死路径下
COPY --from=builder /app/CLIProxyAPI /CLIProxyAPI/CLIProxyAPI

# 2. 🌟 降维打击：把你 GitHub 仓库根目录下的真实 config.yaml 物理拍进最终镜像的死路径下！
COPY config.yaml /CLIProxyAPI/config.yaml

# 3. 顺便保留原作者的示例文件
COPY config.example.yaml /CLIProxyAPI/config.example.yaml

# 4. 强行赋予配置文件最高读写权限，防止 Go 内核因权限锁死拒绝读取
RUN chmod 777 /CLIProxyAPI/config.yaml

WORKDIR /CLIProxyAPI

EXPOSE 8317

ENV TZ=Asia/Shanghai

RUN cp /usr/share/zoneinfo/${TZ} /etc/localtime && echo "${TZ}" > /etc/timezone

# 终极启动：直接执行这个死路径下的可执行程序
CMD ["./CLIProxyAPI"]
