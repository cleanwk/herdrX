"""Destructive only to objects this script creates on an explicitly named parity socket."""
import argparse
import json
import pathlib
import socket
import uuid


def rpc(path, method, params=None):
    request = str(uuid.uuid4())
    with socket.socket(socket.AF_UNIX) as client:
        client.settimeout(15)
        client.connect(path)
        client.sendall((json.dumps(dict(id=request, method=method, params=params or {})) + '\n').encode())
        response = json.loads(client.makefile('rb').readline())
        assert response['id'] == request
        if 'error' in response:
            raise RuntimeError(response['error'])
        return response['result']


def run(path, output):
    assert 'herdrx-parity-' in path, 'Use a disposable, independently named herdrx-parity-* session'
    root = pathlib.Path('/tmp/herdrx-fixture')
    for name in ['atlas', 'docs']:
        (root / name).mkdir(parents=True, exist_ok=True)
    (root / 'atlas' / 'README.txt').write_text('HerdrX anonymous fixture\n中文文件预览 · ASCII 0123456789\n')
    before = rpc(path, 'session.snapshot')['snapshot']
    created = rpc(path, 'workspace.create', dict(cwd=str(root / 'atlas'), label='长名称中文工作空间与英文 Project Atlas', focus=False))
    workspace = created['workspace']['workspace_id']
    after = rpc(path, 'session.snapshot')['snapshot']
    assert len(after['workspaces']) == len(before['workspaces']) + 1
    assert len(after['tabs']) == len(before['tabs']) + 1
    assert len(after['panes']) == len(before['panes']) + 1
    pane = next(p for p in after['panes'] if p['workspace_id'] == workspace)
    rpc(path, 'workspace.report_metadata', dict(workspace_id=workspace, source='parity-fixture', tokens={'branch': 'feature/parity'}))
    second = rpc(path, 'tab.create', dict(workspace_id=workspace, label='Implementation', focus=False))
    second_id = second['tab']['tab_id']
    rpc(path, 'tab.rename', dict(tab_id=pane['tab_id'], label='Review'))
    rpc(path, 'tab.move', dict(tab_id=second_id, insert_index=0))
    cwd = rpc(path, 'pane.get', dict(pane_id=pane['pane_id']))['pane']
    path_value = cwd.get('foreground_cwd') or cwd['cwd']
    split = rpc(path, 'pane.split', dict(target_pane_id=pane['pane_id'], direction='right', cwd=path_value, focus=False))
    split_id = split['pane']['pane_id']
    rpc(path, 'pane.split', dict(target_pane_id=split_id, direction='down', cwd=path_value, focus=False))
    docs = rpc(path, 'workspace.create', dict(cwd=str(root / 'docs'), label='文档', focus=False))['workspace']['workspace_id']
    final = rpc(path, 'session.snapshot')['snapshot']
    for p in final['panes']:
        if p['workspace_id'] in [workspace, docs]:
            rpc(path, 'pane.send_text', dict(pane_id=p['pane_id'], text="PROMPT='fixture $ '; RPROMPT=''; clear; printf 'HerdrX fixture · real PTY\\n'"))
            rpc(path, 'pane.send_keys', dict(pane_id=p['pane_id'], keys=['Enter']))
    result = dict(status='PASS', checks=['workspace.create adds one workspace/tab/pane', 'pane cwd obtained from target server', 'tab rename/move', 'two nested splits', 'real PTY input sent'], mapping={'atlas': workspace, 'docs': docs, 'review': pane['tab_id'], 'implementation': second_id, 'rootPane': pane['pane_id']}, snapshot=rpc(path, 'session.snapshot')['snapshot'])
    pathlib.Path(output).write_text(json.dumps(result, ensure_ascii=False, indent=2) + '\n')
    print(json.dumps({k: v for k, v in result.items() if k != 'snapshot'}, ensure_ascii=False))


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--socket', required=True)
    parser.add_argument('--output', required=True)
    args = parser.parse_args()
    run(args.socket, args.output)
