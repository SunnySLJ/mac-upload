#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
定时检查平台登录状态脚本
根据 login_check_config.json 配置执行登录检查
"""
import json
import sys
from pathlib import Path
from datetime import datetime

# 添加项目路径
PROJECT_ROOT = Path(__file__).resolve().parents[3]
if str(PROJECT_ROOT) not in sys.path:
    sys.path.insert(0, str(PROJECT_ROOT))

from skills.auth.scripts.platform_login import check_platform_login, auto_recover_session, close_connect_browser

STATE_PATH = Path(__file__).parent.parent / "login_check_state.json"

def load_config():
    """加载配置文件"""
    config_path = Path(__file__).parent.parent / "login_check_config.json"
    if not config_path.exists():
        print(f"❌ 配置文件不存在：{config_path}")
        return None
    
    with open(config_path, 'r', encoding='utf-8') as f:
        return json.load(f)


def load_state():
    """加载每日重登计数状态"""
    if not STATE_PATH.exists():
        return {"date": datetime.now().strftime("%Y-%m-%d"), "relogin_counts": {}}

    try:
        with open(STATE_PATH, 'r', encoding='utf-8') as f:
            state = json.load(f)
    except Exception:
        state = {}

    today = datetime.now().strftime("%Y-%m-%d")
    if state.get("date") != today:
        return {"date": today, "relogin_counts": {}}

    counts = state.get("relogin_counts", {})
    if not isinstance(counts, dict):
        counts = {}
    return {"date": today, "relogin_counts": counts}


def save_state(state):
    """保存每日重登计数状态"""
    with open(STATE_PATH, 'w', encoding='utf-8') as f:
        json.dump(state, f, ensure_ascii=False, indent=2)


def can_trigger_relogin(state, platform, max_relogin_per_day):
    """判断当天是否还能继续触发重登"""
    if max_relogin_per_day <= 0:
        return False
    return int(state["relogin_counts"].get(platform, 0)) < max_relogin_per_day


def mark_relogin_attempt(state, platform):
    """记录一次重登触发"""
    current = int(state["relogin_counts"].get(platform, 0))
    state["relogin_counts"][platform] = current + 1

def check_all_platforms(config):
    """检查所有配置的平​​台登录状态"""
    results = []
    state = load_state()
    max_relogin_per_day = int(config.get("max_relogin_per_day", 5) or 0)
    
    print('='*60)
    print(f'🦐 龙虾上传 - 定时登录状态检查')
    print(f'⏰ 检查时间：{datetime.now().strftime("%Y-%m-%d %H:%M:%S")}')
    print('='*60)
    
    for platform in config.get("platforms", []):
        label_map = {
            'douyin': '抖音',
            'xiaohongshu': '小红书',
            'kuaishou': '快手',
            'shipinhao': '视频号'
        }
        label = label_map.get(platform, platform)
        today_count = int(state["relogin_counts"].get(platform, 0))

        if config.get("auto_retry_login", True) and not can_trigger_relogin(state, platform, max_relogin_per_day):
            print(f'⏭️  {label}: 今日已达到 {max_relogin_per_day} 次重登上限，跳过今日后续检测')
            results.append({
                'platform': platform,
                'status': 'skipped',
                'message': f'{label} 今日已达到重登上限，跳过今日检测',
                'recovered': False,
                'relogin_skipped_today': True,
                'relogin_trigger_count_today': today_count,
            })
            print()
            continue
        
        # 检查登录状态（passive=False 会自动启动 Chrome）
        ok, msg = check_platform_login(platform, PROJECT_ROOT, passive=False)
        
        if ok:
            print(f'✅ {label}: 已登录')
            results.append({'platform': platform, 'status': 'ok', 'message': msg})
        else:
            print(f'❌ {label}: {msg}')
            results.append({'platform': platform, 'status': 'expired', 'message': msg})
            
            # 如果需要自动重试登录
            if config.get("auto_retry_login", True):
                results[-1]['relogin_trigger_count_today'] = today_count

                if can_trigger_relogin(state, platform, max_relogin_per_day):
                    next_count = today_count + 1
                    print(f'   🔄 尝试自动恢复 {label} 会话...（今日第 {next_count}/{max_relogin_per_day} 次）')
                    mark_relogin_attempt(state, platform)
                    save_state(state)
                    success, recover_msg = auto_recover_session(platform, PROJECT_ROOT)
                    results[-1]['relogin_trigger_count_today'] = int(state["relogin_counts"].get(platform, 0))
                    if success:
                        print(f'   ✅ {label} 恢复成功')
                        results[-1]['recovered'] = True
                        results[-1]['relogin_skipped_today'] = False
                    else:
                        print(f'   ❌ {label} 恢复失败：{recover_msg}')
                        results[-1]['recovered'] = False
                        results[-1]['relogin_skipped_today'] = False
                        results[-1]['recover_message'] = recover_msg
                else:
                    print(f'   ⏭️  {label} 今日已达到 {max_relogin_per_day} 次重登上限，今天跳过')
                    results[-1]['recovered'] = False
                    results[-1]['relogin_skipped_today'] = True
                    results[-1]['relogin_trigger_count_today'] = today_count
                    results[-1]['recover_message'] = f'{label} 今日已达到重登上限，跳过自动恢复'
        
        # 检查完关闭浏览器
        close_connect_browser(platform)
        print()
    
    print('='*60)
    
    # 汇总结果
    ok_count = sum(1 for r in results if r['status'] == 'ok')
    total = len(results)
    print(f'📊 结果汇总：{ok_count}/{total} 平台已登录')
    
    if ok_count < total:
        expired_platforms = [r['platform'] for r in results if r['status'] == 'expired']
        print(f'⚠️  需要重新登录的平台：{", ".join(expired_platforms)}')
    
    return results

def main():
    """主函数"""
    config = load_config()
    if not config:
        sys.exit(1)
    
    if not config.get("enabled", True):
        print("⏸️  定时检查已禁用")
        sys.exit(0)
    
    results = check_all_platforms(config)
    
    # 如果有平台登录失效且需要通知
    expired = [r for r in results if r['status'] == 'expired']
    if expired and config.get("notify_on_failure", True):
        print("\n📬 准备发送通知...")
        # 这里可以集成微信通知逻辑
        # 暂时先打印提示
        print("   （通知功能已预留，可集成到现有通知系统）")
    
    # 返回结果供 cron 使用
    print(json.dumps({
        'timestamp': datetime.now().isoformat(),
        'results': results,
        'summary': {
            'total': len(results),
            'ok': sum(1 for r in results if r['status'] == 'ok'),
            'expired': len(expired)
        }
    }, ensure_ascii=False))

if __name__ == "__main__":
    main()
