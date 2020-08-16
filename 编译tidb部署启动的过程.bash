编译tidb部署启动的过程：

1. 下载源代码：
git clone https://github.com/pingcap/tidb.git
git clone https://github.com/pingcap/pd.git
git clone https://github.com/pingcap/tikv.git

2. 本地部署go1.13版本
export GOPROXY="https://goproxy.io"

3. 安装rust

###由于官方地址下载失败，网上查到用国内源

### linux 安装用这个curl https://mirrors.tuna.tsinghua.edu.cn/rustup/rustup/archive/1.21.1/x86_64-unknown-linux-gnu/rustup-init > rustup-init

curl https://mirrors.tuna.tsinghua.edu.cn/rustup/rustup/archive/1.21.1/x86_64-apple-darwin/rustup-init > rustup-init

./rustup-init -v -y --no-modify-path
export PATH="$HOME/.cargo/bin:$PATH" #加入profile

rustc --version
rustc 1.45.2 (d3fb005a3 2020-07-31)

### 编译tikv失败，后来查到是要加入此配置
cat ~/.cargo/config
[source.crates-io]
registry = "https://github.com/rust-lang/crates.io-index"
replace-with = 'tuna'
[source.tuna]
registry = "https://mirrors.tuna.tsinghua.edu.cn/git/crates.io-index.git"

4.编译
分别进入tidb，pd，tikv目录，执行make

5.新建目录启动tidb

#新建tidb-deploy 和 tidb-data

#tree tidb-deploy 
pd-2379/
├── bin
│   └── pd-server
├── conf
│   ├── pd.toml
├── log
│   ├── pd.log
│   └── pd_stderr.log
└── scripts
    └── run_pd.sh

tikv-20160
├── bin
│   └── tikv-server
├── conf
│   └── tikv.toml
├── log
│   ├── tikv.log
│   └── tikv_stderr.log
└── scripts
    └── run_tikv.sh
tikv-20161
├── bin
│   └── tikv-server
├── conf
│   └── tikv.toml
├── log
│   ├── tikv.log
│   └── tikv_stderr.log
└── scripts
    └── run_tikv.sh

tikv-20162
├── bin
│   └── tikv-server
├── conf
│   └── tikv.toml
├── log
│   ├── tikv.log
│   └── tikv_stderr.log
└── scripts
    └── run_tikv.sh

tidb-4000
├── bin
│   └── tidb-server
├── conf
│   └── tidb.toml
├── log
│   ├── tidb.log
│   ├── tidb_slow_query.log
│   └── tidb_stderr.log
└── scripts
    └── run_tidb.sh


6. 启动并连接

### ulimit -n 82920

bin/pd-server \
    --name="pd-127.0.0.1-2379" \
    --client-urls="http://0.0.0.0:2379" \
    --advertise-client-urls="http://127.0.0.1:2379" \
    --peer-urls="http://127.0.0.1:2380" \
    --advertise-peer-urls="http://127.0.0.1:2380" \
    --data-dir="/data1/tidb-data/pd-2379" \
    --initial-cluster="pd-127.0.0.1-2379=http://127.0.0.1:2380" \
    --config=conf/pd.toml \
    --log-file="/data1/tidb-deploy/pd-2379/log/pd.log" 2>> "/data1/tidb-deploy/pd-2379/log/pd_stderr.log"

bin/tikv-server \
    --addr "0.0.0.0:20160" \
    --advertise-addr "127.0.0.1:20160" \
    --status-addr "127.0.0.1:20180" \
    --pd "127.0.0.1:2379" \
    --data-dir "/data1/tidb-data/tikv-20160" \
    --config conf/tikv.toml \
    --log-file "/data1/tidb-deploy/tikv-20160/log/tikv.log" 2>> "/data1/tidb-deploy/tikv-20160/log/tikv_stderr.log"

bin/tidb-server \
    -P 4000 \
    --status="10080" \
    --host="0.0.0.0" \
    --advertise-address="127.0.0.1" \
    --store="tikv" \
    --config="conf/tidb.toml" \
    --path="127.0.0.1:2379" \
    --log-slow-query="log/tidb_slow_query.log" \
    --config=conf/tidb.toml \
    --log-file="/data1/tidb-deploy/tidb-4000/log/tidb.log" 2>> "/data1/tidb-deploy/tidb-4000/log/tidb_stderr.log"


maoshoupingdeMacBook-Pro:pd-2379 maoshouping$ mysql -uroot -h127.0.0.1 -P4000
Welcome to the MySQL monitor.  Commands end with ; or \g.
Your MySQL connection id is 2
Server version: 5.7.25-TiDB-v4.0.0-beta.2-960-g5184a0d70-dirty TiDB Server (Apache License 2.0) Community Edition, MySQL 5.7 compatible

Type 'help;' or '\h' for help. Type '\c' to clear the current input statement.

mysql>            

以上，tidb终于安装成功了！


7. 修改源代码，启动事务时输出日志


在session.go 中Parse函数中加入如下内容，让tidb的日志打印 begin transaction。

	if len(stmts) != 0 {
		if (strings.Contains(strings.ToLower(stmts[0].Text()),"begin" ) || strings.Contains(strings.ToLower(stmts[0].Text()),"transaction" )){
			logutil.BgLogger().Info("begin transaction", zap.String("SQL", stmts[0].Text()))

		}

	}

修改后如下：
func (s *session) Parse(ctx context.Context, sql string) ([]ast.StmtNode, error) {

    .........省略 .......


	for _, warn := range warns {
		s.sessionVars.StmtCtx.AppendWarning(util.SyntaxWarn(warn))
	}
	if len(stmts) != 0 {
		if (strings.Contains(strings.ToLower(stmts[0].Text()),"begin" ) || strings.Contains(strings.ToLower(stmts[0].Text()),"transaction" )){
			logutil.BgLogger().Info("begin transaction", zap.String("SQL", stmts[0].Text()))

		}

	}

	return stmts, nil
}



在客户端验证：
Type 'help;' or '\h' for help. Type '\c' to clear the current input statement.

mysql> begin;
Query OK, 0 rows affected (0.00 sec)

mysql>


查看日志输出，能显示出加入的begin transaction

[2020/08/16 10:23:57.397 +08:00] [INFO] [gc_worker.go:1476] ["[gc worker] sent safe point to PD"] [uuid=5cfd1d34d180005] ["safe point"=418786557893279744]
[2020/08/16 10:24:24.836 +08:00] [INFO] [session.go:1117] ["begin transaction"] [SQL=begin]







