import asyncio
import os
from typing import Final, Self
from sciffi.cosmo import message

VERSION: Final[int] = 0
ENVNAME: Final[str] = "SCIFFI_PORT"


class Client:
    msgid: int
    host: str
    port: int
    _writer: asyncio.StreamWriter
    _reader: asyncio.StreamReader

    def __init__(self, host: str = "127.0.0.1", port: int | None = None) -> None:
        self.host = host
        self.port = port or int(os.environ[ENVNAME])
        self.msgid = 0

    async def connect(self) -> Self:
        self._reader, self._writer = await asyncio.open_connection(
            host=self.host,
            port=self.port,
        )
        self._writer.write(message.HandshakeMessage(version=VERSION).pack())
        return self

    async def write(self, data: str) -> None:
        self.msgid += 1
        self._writer.write(message.WriteMessage(data=data).pack(msgid=self.msgid))

    async def close(self) -> None:
        self.msgid += 1
        self._writer.write(message.CloseMessage().pack(msgid=self.msgid))

    async def __aenter__(self) -> Self:
        await self.connect()
        return self

    async def __aexit__(self, *_) -> None:
        await self.close()
