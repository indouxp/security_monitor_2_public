#!/bin/bash
################################################################################
# 概要        : release.txt に基づきローカルからリモートへファイルをリリースする
# Created     : 2026-05-05
# Last updated: 2026-05-18
# Author      : Tsystem
# 使用方法    : ./release.sh [-c config_file] user@host
#               デフォルトのファイルリスト: カレントディレクトリの release.txt
# リストフォーマット:
#   # コメント行
#   :local:path/to:file /remote/path/to/file
#   ":local:path with:spaces" "/remote/path with spaces"
# 更新履歴:
#   2026-05-05: 初版
#   2026-05-18: 差分時は常に確認(自動リリース廃止)、新規も確認。処理結果メッセージを明確化
################################################################################
set -eEuo pipefail
# -e  : コマンドが失敗したら即時終了
# -E  : ERRトラップを関数・サブシェル・コマンド置換にも継承させる
# -u  : 未定義変数の参照をエラー扱い
# -o pipefail : パイプ内のいずれかが失敗したらエラー扱い

readonly MY_NAME="${0##*/}"                                  # 自スクリプトのファイル名
MY_DIR=$(cd "$(dirname "$0")" && pwd)                        # 自スクリプトの絶対パス
readonly MY_DIR
readonly LOG_DIR="${LOG_DIR:-/tmp}"                          # ログ出力先ディレクトリ
LOG_NAME="$(date '+%Y%m%d.%H%M%S').${HOSTNAME}.${MY_NAME}.$$.log"
readonly LOG_NAME                                            # ログファイル名
readonly LOG_PATH="${LOG_DIR}/${LOG_NAME}"                   # ログファイルのフルパス

exit_code=0                                                  # 最終的な終了コード（トラップで更新）
err_line=0                                                   # エラー発生行番号
TMP_DIR=""                                                   # 一時ディレクトリパス（on_exit でクリーンアップ）

[[ -d "$LOG_DIR" ]] || {
  echo "${MY_NAME}: ${LOG_DIR}が存在しません。" 1>&2
  exit 1
}

# 画面とログの両方に出力
exec > >(tee -a "$LOG_PATH") 2>&1

################################################################################
# 関数定義
#-------------------------------------------------------------------------------
# 概要     : タイムスタンプ付きでメッセージを標準出力に書き出す
# 引数     : $1 - 出力するメッセージ文字列
# 戻り値   : なし
#-------------------------------------------------------------------------------
info() {
  local msg="$1"                                   # 出力対象メッセージ
  echo "$(date '+%Y%m%d.%H%M%S.%N'): ${msg}"
}

#-------------------------------------------------------------------------------
# 概要     : 使用方法を標準エラーに表示する
# 引数     : なし
# 戻り値   : なし
#-------------------------------------------------------------------------------
usage() {
  echo "Usage: ${MY_NAME} [-c config_file] user@host" >&2
  echo "  user@host      : リモートホスト (必須)" >&2
  echo "  -c config_file : リリースリスト (デフォルト: ./release.txt)" >&2
}

#-------------------------------------------------------------------------------
# 概要     : ERRトラップ。エラー発生時に行番号と直前ステータスを記録する
# 引数     : $1 - エラーが発生した行番号 (LINENO)
# 戻り値   : なし
#-------------------------------------------------------------------------------
on_err() {
  local rc=$?                                      # 最初に必ず $? を退避
  exit_code=$rc                                    # 失敗コマンドの戻り値を保存
  err_line=$1                                      # 発生行番号を保存
  sed -n "${err_line}p" "$0"                       # エラー行出力（$0 をクォートして空白対応）
  info "ERROR LINE=${err_line} STATUS=${exit_code}"
  # ここでは exit せず、EXITトラップに後始末を委ねる
}
trap 'on_err ${LINENO}' ERR

#-------------------------------------------------------------------------------
# 概要     : SIGINT/SIGTERM/SIGQUIT トラップ。シグナル受信を記録し終了する
# 引数     : $1 - シグナル名 (INT, TERM, QUIT)
# 戻り値   : なし
#-------------------------------------------------------------------------------
on_signal() {
  local sig="$1"                                   # 受信したシグナル名
  case "$sig" in
    INT)  exit_code=130 ;;                         # Ctrl+C
    TERM) exit_code=143 ;;                         # kill
    QUIT) exit_code=131 ;;                         # Ctrl+\
    *)    exit_code=128 ;;
  esac
  # tee も同時に SIGINT を受けて終了するため、
  # tee パイプへの書き込みをやめ、ログファイルと端末に直接書く
  trap '' PIPE                                     # 先に SIGPIPE を無効化
  local msg
  msg="$(date '+%Y%m%d.%H%M%S.%N'): SIGNAL ${sig} caught"
  echo "$msg" >> "$LOG_PATH" 2>/dev/null || true
  if [[ -t 1 ]]; then                              # ターミナルが標準出力の場合
    echo "$msg" > /dev/tty 2>/dev/null || true
  fi
  exit "${exit_code}"
}
trap 'on_signal INT'  INT
trap 'on_signal TERM' TERM
trap 'on_signal QUIT' QUIT                         # Ctrl+\

#-------------------------------------------------------------------------------
# 概要     : EXITトラップ。一時ディレクトリを削除し終了コードを記録する
# 引数     : なし
# 戻り値   : なし
#-------------------------------------------------------------------------------
on_exit() {
  local rc=$?                                      # 最初に必ず $? を退避
  trap '' PIPE                                     # tee 終了後の SIGPIPE を無視
  [[ $exit_code -eq 0 ]] && exit_code=$rc

  # 一時ディレクトリの削除
  [[ -n "${TMP_DIR}" && -d "${TMP_DIR}" ]] && rm -rf "${TMP_DIR}"

  # tee がすでに終了している可能性があるため、パイプ経由の stdout は使わない
  local msg
  msg="$(date '+%Y%m%d.%H%M%S.%N'): END rc: ${exit_code}"
  echo "$msg" >> "$LOG_PATH" 2>/dev/null || true   # ログファイルへ直接追記
  if [[ -t 1 ]]; then                              # ターミナルが標準出力の場合
    echo "$msg" > /dev/tty 2>/dev/null || true     # 端末へ直接出力
  else
    echo "$msg" || true
  fi
  exit "${exit_code}"
}
trap 'on_exit' EXIT

#-------------------------------------------------------------------------------
# 概要     : リリストの1行をパースしてローカル・リモートパスを設定する
#            ローカルパスはファイル名そのまま使用する（変換不要）
#            / を含まない場合はカレントディレクトリのファイルとして扱う
#            クォート済みパス（空白含む）は eval で正しく処理する
# 引数     : $1 - パース対象行文字列
#            $2 - ローカルパスを受け取る変数名 (nameref)
#            $3 - リモートパスを受け取る変数名 (nameref)
# 戻り値   : 0=成功, 1=フィールド不足
#-------------------------------------------------------------------------------
parse_line() {
  local line="$1"
  local -n _lpath="$2"                             # ローカルパスを呼び出し元変数に直接セット
  local -n _rpath="$3"                             # リモートパスを呼び出し元変数に直接セット

  local fields=()
  eval "fields=($line)"                            # クォート済みパスをシェル評価でパース

  [[ ${#fields[@]} -lt 2 ]] && return 1

  local raw="${fields[0]}"                         # ローカルパス（変換なしでそのまま使用）
  # / を含まない場合はカレントディレクトリのファイルとして扱う
  if [[ "$raw" != */* ]]; then
    _lpath="./${raw}"
  else
    _lpath="${raw}"
  fi
  _rpath="${fields[1]}"
  return 0
}

#-------------------------------------------------------------------------------
# 概要     : ユーザーに S/Y/C(/D) の選択を求め、結果を変数にセットする
#            プロンプト表示と入力受付は /dev/tty 経由（ループの stdin リダイレクトと競合しない）
#            $3/$4 を指定すると D)iff を選択肢に追加し、d 入力で
#            `diff -u <$3> <$4> | ${PAGER:-less}` を /dev/tty に表示してプロンプトに戻る
# 引数     : $1 - 表示するメッセージ文字列（改行含む可）
#            $2 - 選択結果を受け取る変数名 (nameref): "S", "Y", "C" のいずれかがセットされる
#            $3 - (省略可) diff 左辺ファイルパス（remote tmp）
#            $4 - (省略可) diff 右辺ファイルパス（local）
# 戻り値   : 0 (常に成功)
#-------------------------------------------------------------------------------
confirm() {
  local msg="$1"
  local -n _ans="$2"                               # 選択結果を呼び出し元変数にセット
  local diff_left="${3:-}"                         # diff 左辺（remote tmp）。省略時は D 無効
  local diff_right="${4:-}"                        # diff 右辺（local）
  local has_diff=0                                 # D)iff 有効フラグ
  [[ -n "$diff_left" && -n "$diff_right" ]] && has_diff=1
  local prompt_tail input
  if [[ $has_diff -eq 1 ]]; then
    prompt_tail='  [S)kip / Y)es / D)iff / C)ancel]: '
  else
    prompt_tail='  [S)kip / Y)es / C)ancel]: '
  fi

  while true; do
    printf '%s\n' "${msg}" > /dev/tty              # メッセージ表示（\n も解釈される）
    printf '%s' "${prompt_tail}" > /dev/tty
    read -r input < /dev/tty                       # /dev/tty から読む（while のリダイレクトと競合しない）
    case "$input" in
      [Ss]) _ans="S"; return 0 ;;                  # スキップ
      [Yy]) _ans="Y"; return 0 ;;                  # リリース実行
      [Cc]) _ans="C"; return 0 ;;                  # キャンセル（スクリプト終了）
      [Dd])
        if [[ $has_diff -eq 1 ]]; then
          # tee による stdout パイプ化を回避するため /dev/tty を明示
          diff -u "${diff_left}" "${diff_right}" 2>&1 | "${PAGER:-less}" > /dev/tty 2>&1 || true
        else
          printf 'S, Y, C のいずれかを入力してください。\n' > /dev/tty
        fi
        ;;
      *)
        if [[ $has_diff -eq 1 ]]; then
          printf 'S, Y, D, C のいずれかを入力してください。\n' > /dev/tty
        else
          printf 'S, Y, C のいずれかを入力してください。\n' > /dev/tty
        fi
        ;;
    esac
  done
}

#-------------------------------------------------------------------------------
# 概要     : ローカル→リモートへファイルを転送する
#            remote_path が /home/ または ~/ 始まりでない場合は
#            リモート /tmp 経由で sudo mv する
# 引数     : $1 - local_path  ローカルファイルパス
#            $2 - remote_host リモートホスト (user@host)
#            $3 - remote_path リモートファイルパス
# 戻り値   : 0=成功, 1=失敗
#-------------------------------------------------------------------------------
do_scp() {
  local local_path="$1"    # ローカルファイルパス
  local remote_host="$2"   # リモートホスト (user@host)
  local remote_path="$3"   # リモートファイルパス（ホスト部除く）

  # ホームディレクトリ判定: /home/ または ~/ 始まりなら通常 scp
  if [[ "$remote_path" == /home/* || "$remote_path" == ~/* ]]; then
    scp -p "${local_path}" "${remote_host}:${remote_path}"
    return $?
  fi

  # ホームディレクトリ以外: リモート /tmp 経由で sudo mv
  # リモート TMP_DIR はローカル TMP_DIR と同名 (例: /tmp/release.sh.12345.tmp)
  local remote_tmp_dir="${TMP_DIR}"

  # ファイル名取得: local_path に / を含む場合はファイル名部分のみ使用
  local fname
  if [[ "$local_path" == */* ]]; then
    fname=$(basename "${local_path}")   # パスからファイル名を抽出
  else
    fname="${local_path}"               # ファイル名のみの場合はそのまま使用
  fi

  local remote_tmp_file="${remote_tmp_dir}/${fname}"  # リモート一時ファイルパス

  # リモートに TMP_DIR 作成
  if ! ssh -n "${remote_host}" "mkdir -p '${remote_tmp_dir}'"; then
    info "ERROR: リモート TMP_DIR 作成失敗: ${remote_host}:${remote_tmp_dir}"
    return 1
  fi

  # リモートの TMP_DIR へ scp（タイムスタンプ保持）
  if ! scp -p "${local_path}" "${remote_host}:${remote_tmp_file}"; then
    info "ERROR: scp to リモート /tmp 失敗: ${remote_host}:${remote_tmp_file}"
    return 1
  fi

  # sudo mv で正式パスへ移動
  if ! ssh -n "${remote_host}" "sudo mv '${remote_tmp_file}' '${remote_path}'"; then
    info "ERROR: sudo mv 失敗: ${remote_host}:${remote_tmp_file} → ${remote_path}"
    return 1
  fi

  return 0
}

#-------------------------------------------------------------------------------
# 概要     : 主処理。release.txt を読み込みローカル→リモートへリリースする
#            ・差分なし → スキップ
#            ・差分あり → 確認後 scp (local → remote) / スキップ / キャンセル
#            ・リモートに未存在（新規）→ 確認後 scp / スキップ / キャンセル
# 引数     : $@ - コマンドライン引数
# 戻り値   : 0=正常終了, 1=エラーあり
#-------------------------------------------------------------------------------
main() {
  local remote_host=""            # 位置引数で指定するリモートホスト (user@host)
  local txt_file="./release.txt"  # リリースリストファイルパス
  local opt

  # オプション解析
  while getopts "c:" opt; do
    case "$opt" in
      c) txt_file="$OPTARG" ;;
      *) usage; exit 1 ;;
    esac
  done
  shift $((OPTIND - 1))

  # 位置引数: user@host (必須)
  if [[ $# -lt 1 ]]; then
    info "ERROR: user@host が指定されていません"
    usage; exit 1
  fi
  remote_host="$1"

  # ファイルリスト存在確認
  if [[ ! -f "$txt_file" ]]; then
    info "ERROR: ${txt_file} が見つかりません"
    exit 1
  fi

  # 一時ディレクトリ作成 (on_exit でクリーンアップ)
  TMP_DIR="/tmp/${MY_NAME}.$$.tmp"
  mkdir -p "${TMP_DIR}"
  info "TMP_DIR: ${TMP_DIR}"

  local line_no=0                 # 現在処理中の行番号
  local ok_cnt=0                  # リリース成功件数
  local skip_cnt=0                # スキップ件数
  local err_cnt=0                 # エラー件数

  while IFS= read -r line; do
    line_no=$(( line_no + 1 ))

    # コメント行・空行をスキップ
    [[ "$line" =~ ^[[:space:]]*# ]] && continue
    [[ -z "${line//[[:space:]]/}" ]] && continue

    # 行パース
    local local_path=""            # ローカルファイルの絶対パス
    local remote_path=""           # リモートファイルのパス（ホスト部除く）
    if ! parse_line "$line" local_path remote_path; then
      info "WARN [行${line_no}]: フィールド不足のためスキップ: ${line}"
      err_cnt=$(( err_cnt + 1 ))
      continue
    fi

    info "--- [行${line_no}] local=${local_path}  remote=${remote_host}:${remote_path}"

    # ローカルファイル存在確認
    if [[ ! -f "$local_path" ]]; then
      info "ERROR: ローカルファイルが存在しません: ${local_path}"
      err_cnt=$(( err_cnt + 1 ))
      continue
    fi

    # リモートファイルを一時ディレクトリへ取得（タイムスタンプ保持）
    # リモートパス中の / を _ に置換して一時ファイル名を生成（パス衝突回避）
    local tmp_file="${TMP_DIR}/${remote_path//\//_}"
    local local_size                # ローカルファイルのサイズ (bytes)
    local_size=$(stat -c '%s' "${local_path}")
    local user_ans=""               # ユーザーの選択結果 (S/Y/C)
    local prompt_msg                 # 確認プロンプト文字列

    if ! scp -p "${remote_host}:${remote_path}" "${tmp_file}" 2>/dev/null; then
      # リモートにファイルが存在しない → 新規リリース（要確認）
      prompt_msg=$(printf \
        'リモートにファイルが存在しません。新規リリースしますか?\n  local : %s (%s bytes)\n  remote: %s (なし)' \
        "${local_path}" "${local_size}" "${remote_host}:${remote_path}")
      confirm "${prompt_msg}" user_ans
      case "$user_ans" in
        Y)
          do_scp "${local_path}" "${remote_host}" "${remote_path}"
          info "リリースしました。(新規): ${local_path} → ${remote_host}:${remote_path}"
          ok_cnt=$(( ok_cnt + 1 ))
          ;;
        S)
          info "リリースをスキップしました。: ${local_path}"
          skip_cnt=$(( skip_cnt + 1 ))
          ;;
        C)
          info "CANCEL: ユーザーによりキャンセルされました"
          exit 0
          ;;
      esac
      continue
    fi

    local remote_size               # リモートファイルのサイズ (bytes)
    remote_size=$(stat -c '%s' "${tmp_file}")

    # 差分チェック（サイズ・内容の差違）。差分なし → スキップ
    if diff -q "${local_path}" "${tmp_file}" > /dev/null 2>&1; then
      info "差分なし (local=${local_size} bytes / remote=${remote_size} bytes)"
      info "リリースをスキップしました。: ${local_path}"
      skip_cnt=$(( skip_cnt + 1 ))
      continue
    fi

    # 差分あり → どちらが新しいかを補足表示して確認
    local local_mtime remote_mtime newer
    local_mtime=$(stat -c '%Y' "${local_path}")
    remote_mtime=$(stat -c '%Y' "${tmp_file}")
    if   [[ $local_mtime -gt $remote_mtime ]]; then newer="local が新しい"
    elif [[ $local_mtime -lt $remote_mtime ]]; then newer="remote が新しい"
    else                                            newer="更新時刻は同じ"
    fi

    prompt_msg=$(printf \
      'ファイルに差分があります。リリースしますか?\n  local : %s (%s bytes)\n  remote: %s (%s bytes)\n  ※ %s' \
      "${local_path}" "${local_size}" \
      "${remote_host}:${remote_path}" "${remote_size}" \
      "${newer}")
    # D)iff 用に remote tmp と local を渡す（diff -u remote local: + が local 側）
    confirm "${prompt_msg}" user_ans "${tmp_file}" "${local_path}"
    case "$user_ans" in
      Y)
        do_scp "${local_path}" "${remote_host}" "${remote_path}"
        info "リリースしました。: ${local_path} → ${remote_host}:${remote_path}"
        ok_cnt=$(( ok_cnt + 1 ))
        ;;
      S)
        info "リリースをスキップしました。: ${local_path}"
        skip_cnt=$(( skip_cnt + 1 ))
        ;;
      C)
        info "CANCEL: ユーザーによりキャンセルされました"
        exit 0
        ;;
    esac

  done < "${txt_file}"

  info "完了: リリース=${ok_cnt}件  スキップ=${skip_cnt}件  エラー=${err_cnt}件"
  [[ $err_cnt -gt 0 ]] && exit_code=1
  return 0
}

################################################################################
# 実行
info "START host: ${HOSTNAME} name: ${MY_NAME} dir: ${MY_DIR}"
main "$@"
