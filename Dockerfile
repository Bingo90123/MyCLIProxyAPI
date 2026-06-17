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

RUN CGO_ENABLED=1 GOOS=linux go build -buildvcs=false -ldflags="-s -w -X 'main.Version=${VERSION}' -X 'main.Commit=${COMMIT}' -X 'main.BuildDate=${BUILD_DATE}'" -o ./CLIProxyAPI ./cmd/server/

# ================= 第二阶段：构建最终运行环境 =================
FROM debian:bookworm

RUN apt-get update && apt-get install -y --no-install-recommends tzdata ca-certificates && rm -rf /var/lib/apt/lists/*

# 创建项目死路径
RUN mkdir -p /CLIProxyAPI

# 1. 从第一阶段编译环境里，把可执行文件复制过来
COPY --from=builder /app/CLIProxyAPI /CLIProxyAPI/CLIProxyAPI

# 2. 🌟 核心修正：彻底删掉 COPY，改用 echo 在编译期强行凭空写出带 0.0.0.0 的配置文件
RUN echo 'server:' > /CLIProxyAPI/config.yaml && \
    echo '  host: "0.0.0.0"' >> /CLIProxyAPI/config.yaml && \
    echo '  port: 8317' >> /CLIProxyAPI/config.yaml && \
    echo '  management: true' >> /CLIProxyAPI/config.yaml && \
    echo 'providers:' >> /CLIProxyAPI/config.yaml && \
    echo '  openai: []' >> /CLIProxyAPI/config.yaml && \
    echo '  anthropic: []' >> /CLIProxyAPI/config.yaml && \
    echo '  gemini: []' >> /CLIProxyAPI/config.yaml

# 3. 保留原作者的示例文件
COPY config.example.yaml /CLIProxyAPI/config.example.yaml

# 4. 赋予最高权限
RUN chmod 777 /CLIProxyAPI/config.yaml

WORKDIR /CLIProxyAPI

EXPOSE 8317

# 5. 锁死环境变量，双保险
ENV PORT=8317
ENV HOST=0.0.0.0
ENV TZ=Asia/Shanghai

RUN cp /usr/share/zoneinfo/${TZ} /etc/localtime && echo "${TZ}" > /etc/timezone

# 启动程序
CMD ["./CLIProxyAPI"]
