"""Read-only synthetic Agent metadata for native UI load tests; no terminals run here."""
import argparse, asyncio, json, pathlib, signal


def snapshot(count):
    spaces = [dict(workspace_id=f'w{x}', label=f'性能夹具 {x}', tokens={'branch': 'fixture/performance'}) for x in range(4)]
    tabs = [dict(tab_id=f'w{x}:t1', workspace_id=f'w{x}', label='Fixture') for x in range(4)]
    panes = [dict(pane_id=f'w{i%4}:p{i}', workspace_id=f'w{i%4}', tab_id=f'w{i%4}:t1', terminal_id=f'fixture-{i}', agent=['codex','claude','gemini','kimi'][i%4], agent_status=['blocked','working','done','idle','unknown'][i%5], title=f'登录修复与终端性能任务 {i:03}', cwd='/tmp/herdrx-ux-metadata', tokens={}) for i in range(count)]
    return dict(workspaces=spaces, tabs=tabs, panes=panes, layouts=[])

async def main(args):
    path=pathlib.Path(args.socket)
    assert str(path).startswith('/tmp/herdrx-ux-') and not path.exists()
    data=snapshot(args.count)
    async def serve(reader, writer):
        try:
            req=json.loads(await reader.readline()); method=req['method']; ident=req['id']
            if method=='session.snapshot':result={'snapshot':data}
            elif method=='events.subscribe':result={'type':'subscription_started'}
            else:
                writer.write((json.dumps({'id':ident,'error':{'message':'Read-only metadata fixture; no terminal or writes'}})+'\n').encode());await writer.drain();return
            writer.write((json.dumps({'id':ident,'result':result})+'\n').encode());await writer.drain()
            if method=='events.subscribe':await reader.read()
        except (ConnectionError,ValueError):pass
        finally:writer.close()
    server=await asyncio.start_unix_server(serve,str(path))
    stop=asyncio.Event()
    for sig in (signal.SIGINT,signal.SIGTERM):asyncio.get_running_loop().add_signal_handler(sig,stop.set)
    print(f'{args.count} synthetic Agent rows at {path}',flush=True)
    await stop.wait();server.close();await server.wait_closed();path.unlink(missing_ok=True)

if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('--socket',required=True);p.add_argument('--count',type=int,default=200);asyncio.run(main(p.parse_args()))
