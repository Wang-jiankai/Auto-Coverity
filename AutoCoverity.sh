#!/bin/sh

# ===== 第一部分：准备环境 =====
TMP_DIR=$(pwd)
# 你需要针对本地环境修改的项
COVERITY_DIR="$HOME/cov-analysis-linux64-2023.9.0" # 你的coverity目录
BASE_DIR="$HOME/diskxxx/namexxx/parent" # 父仓库目录
PARENT_REPO_DIR="$BASE_DIR"  # 显式定义父工程目录
PROJECTS="childa childb childc childd childe" # 子工程列表，列出所有子仓库的名字
COVERITY_OUTPUT_BASE="$HOME/diskxxx/namexxx/coverity-output" # 过程文件存放目录
COV_SERVER_URL="http://192.168.001.001:0123" # 你的coverity服务器地址
COV_USER="CoverityAccount"
COV_PROJECT="ProjectName"
# COV_PASS_FILE="$BASE_DIR/.coverity_pass" # 可以将密码存放在本地文件
# 检查密码文件是否存在
# if [ ! -f "$COV_PASS_FILE" ]; then
#     echo "error: Coverity 密码文件不存在: $COV_PASS_FILE"
#     echo "请创建包含密码的文件并设置权限: chmod 600 $COV_PASS_FILE"
#     exit 1
# fi

COV_BUILD="$COVERITY_DIR/bin/cov-build" # build命令
COV_ANALYZE="$COVERITY_DIR/bin/cov-analyze" # analyze命令
COV_FORMAT="$COVERITY_DIR/bin/cov-format-errors" # Format命令
COV_COMMIT="$COVERITY_DIR/bin/cov-commit-defects"  # commit命令
REPORT_DIR="$BASE_DIR/coverity-reports"  # HTML报告集中存放目录
LOG_DIR="$BASE_DIR/logs" # 编译log集中存放目录
mkdir -p "$LOG_DIR" "$REPORT_DIR"
TOTAL_PROJECTS=$(echo $PROJECTS | wc -w)
COUNT=0
GENERATE_LOCAL_REPORT=false  # 设为false可关闭本地报告生成


# ===== 第二部分：编译并分析 =====
run_coverity() {
    local project="$1"
    local status=0
    
    local PROJECT_DIR="$BASE_DIR/$project" # 子工程目录
    local COVERITY_BUILD_DIR="$COVERITY_OUTPUT_BASE/$project" # 子工程过程文件目录
    local PROJECT_LOG_DIR="$LOG_DIR/$project" # 子工程编译log存放目录
    mkdir -p "$PROJECT_LOG_DIR" "$COVERITY_BUILD_DIR"
    
    case "$project" in
        "childa")COV_STREAM="ProjectName-childa" ;; # 流映射
        "childb")COV_STREAM="ProjectName-childb" ;;
        "childc")COV_STREAM="ProjectName-childc" ;;
        "childd")COV_STREAM="ProjectName-childd" ;;
        "childe")COV_STREAM="ProjectName-childe" ;;
        "childf")COV_STREAM="ProjectName-childf" ;;
        *)            echo "未配置的仓库名: $project"; exit 1 ;;
    esac

    echo "\n<<<<< <<<<< <<<<< <<<<< <<<<< <<<<< <<<<< [1/5] 开始处理项目: $project >>>>> >>>>> >>>>> >>>>> >>>>> >>>>> >>>>>"
    cd "$PROJECT_DIR" || { echo "无法进入项目目录: $PROJECT_DIR"; return 1; }
    make clean

    echo "\n<<<<< <<<<< <<<<< <<<<< <<<<< <<<<< <<<<< [2/5] Coverity构建: $project >>>>> >>>>> >>>>> >>>>> >>>>> >>>>> >>>>>"
    local LOG_FILE="$PROJECT_LOG_DIR/build_$(date +%Y%m%d_%H%M%S).log"
    echo "build time: $(date)"
    echo "project dir: $PROJECT_DIR"
    echo "build dir: $COVERITY_BUILD_DIR"
    echo "Coverity building ..."
    {
        $COV_BUILD --dir "$COVERITY_BUILD_DIR" make
    } > "$LOG_FILE" 2>&1

    # 检查构建状态并简洁化输出
    if [ $? -eq 0 ]; then
        tail -n 2 "$LOG_FILE"
        echo "build log: $LOG_FILE"
        echo "build success !"
    else
        tail -n 5 "$LOG_FILE"
        echo "build fail ! please check log: $LOG_FILE"
        return 1
    fi

    echo "\n<<<<< <<<<< <<<<< <<<<< <<<<< <<<<< <<<<< [3/5] Coverity分析: $project >>>>> >>>>> >>>>> >>>>> >>>>> >>>>> >>>>>"
    $COV_ANALYZE --dir "$COVERITY_BUILD_DIR" --all --enable-constraint-fpp || status=$?
    if [ $status -ne 0 ]; then
        echo "错误: 项目 $project analyze过程中出错"
    fi

    echo "\n<<<<< <<<<< <<<<< <<<<< <<<<< <<<<< <<<<< [4/5] 本地报告生成: $project >>>>> >>>>> >>>>> >>>>> >>>>> >>>>> >>>>>\n"
    if [ "$GENERATE_LOCAL_REPORT" = "true" ]; then
        echo "生成本地HTML报告..."
        # 生成HTML报告到父工程目录;本地备份
        local PROJECT_HTML_DIR="$REPORT_DIR/$project"
        mkdir -p "$PROJECT_HTML_DIR"
        $COV_FORMAT --dir "$COVERITY_BUILD_DIR" --html-output "$PROJECT_HTML_DIR" # 当前存在问题,但不影响远程推送暂不修改
    else
        echo "关闭本地报告生成"
    fi





    return $status
}

echo "\n <<< <<< <<< coverity end >>> >>> >>> \n"