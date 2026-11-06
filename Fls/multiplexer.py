#!/usr/bin/env python3
import asyncio
import sys

SSH_TARGET = ("127.0.0.1", 22)
XRAY_TARGET = ("127.0.0.1", 80)
LISTEN_HOST = "127.0.0.1"
LISTEN_PORT = 10053

async def pipe(reader, writer):
    try:
        while not reader.at_eof():
            data = await reader.read(8192)
            if not data:
                break
            writer.write(data)
            await writer.drain()
    except Exception:
        pass
    finally:
        try:
            writer.close()
            await writer.wait_closed()
        except Exception:
            pass

async def handle_client(client_reader, client_writer):
    target_host, target_port = SSH_TARGET
    initial_data = b""
    try:
        initial_data = await asyncio.wait_for(client_reader.read(4096), timeout=3.0)
    except Exception:
        pass

    if initial_data:
        # Check if HTTP request (Xray WebSocket handshake)
        if any(initial_data.startswith(m) for m in (b"GET ", b"POST ", b"HEAD ", b"HTTP/", b"PRI *")):
            target_host, target_port = XRAY_TARGET
            print(f"[Mux] Forwarding HTTP/WS ({len(initial_data)} bytes) to Xray/Nginx", flush=True)
        else:
            target_host, target_port = SSH_TARGET
            print(f"[Mux] Forwarding Non-HTTP ({len(initial_data)} bytes) to SSH", flush=True)

    try:
        server_reader, server_writer = await asyncio.open_connection(target_host, target_port)
        if initial_data:
            server_writer.write(initial_data)
            await server_writer.drain()
        
        asyncio.create_task(pipe(client_reader, server_writer))
        asyncio.create_task(pipe(server_reader, client_writer))
    except Exception as e:
        print(f"[Mux] Connection failed: {e}", flush=True)
        try:
            client_writer.close()
            await client_writer.wait_closed()
        except Exception:
            pass

async def main():
    server = await asyncio.start_server(handle_client, LISTEN_HOST, LISTEN_PORT)
    async with server:
        await server.serve_forever()

if __name__ == "__main__":
    asyncio.run(main())
