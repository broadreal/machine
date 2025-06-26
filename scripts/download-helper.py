#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
模型下载助手 - 支持断点续传和多线程下载
"""

import os
import sys
import requests
import threading
from pathlib import Path
from concurrent.futures import ThreadPoolExecutor
import time

class ModelDownloader:
    def __init__(self, use_mirror=True):
        self.use_mirror = use_mirror
        self.session = requests.Session()
        self.session.headers.update({
            'User-Agent': 'Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36'
        })
        
    def download_file(self, url, local_path, chunk_size=8192):
        """下载文件with断点续传"""
        local_path = Path(local_path)
        local_path.parent.mkdir(parents=True, exist_ok=True)
        
        # 检查已下载的大小
        resume_pos = 0
        if local_path.exists():
            resume_pos = local_path.stat().st_size
            
        headers = {}
        if resume_pos > 0:
            headers['Range'] = f'bytes={resume_pos}-'
            
        try:
            response = self.session.get(url, headers=headers, stream=True, timeout=30)
            response.raise_for_status()
            
            total_size = int(response.headers.get('content-length', 0)) + resume_pos
            
            mode = 'ab' if resume_pos > 0 else 'wb'
            with open(local_path, mode) as f:
                downloaded = resume_pos
                for chunk in response.iter_content(chunk_size=chunk_size):
                    if chunk:
                        f.write(chunk)
                        downloaded += len(chunk)
                        
                        # 进度显示
                        if total_size > 0:
                            percent = (downloaded / total_size) * 100
                            print(f'\r下载进度: {percent:.1f}% ({downloaded}/{total_size}字节)', end='')
                            
            print(f'\n✅ 下载完成: {local_path}')
            return True
            
        except Exception as e:
            print(f'\n❌ 下载失败: {e}')
            return False
            
    def download_model_from_modelscope(self, model_id, local_dir):
        """从ModelScope下载模型"""
        print(f"从ModelScope下载模型: {model_id}")
        
        try:
            from modelscope.hub.snapshot_download import snapshot_download
            snapshot_download(
                model_id=model_id,
                cache_dir=local_dir,
                local_files_only=False
            )
            print(f"✅ ModelScope模型下载完成: {local_dir}")
            return True
            
        except Exception as e:
            print(f"❌ ModelScope下载失败: {e}")
            return False

if __name__ == "__main__":
    if len(sys.argv) < 3:
        print("用法: python download-helper.py <model_id> <local_dir>")
        sys.exit(1)
        
    model_id = sys.argv[1]
    local_dir = sys.argv[2]
    
    downloader = ModelDownloader()
    success = downloader.download_model_from_modelscope(model_id, local_dir)
    
    if not success:
        sys.exit(1)
