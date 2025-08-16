import struct
from abc import abstractmethod
from dataclasses import dataclass
from enum import IntEnum
from typing import ClassVar, NamedTuple, Protocol, override


class MsgType(IntEnum):
    HANDSHAKE = 0x01
    RESPONSE = 0x02
    GETREGISTER = 0x03
    PUTREGISTER = 0x04
    WRITE = 0x05
    LOG = 0x06
    CLOSE = 0x07


class MessageHeader(NamedTuple):
    tag: MsgType
    id: int
    plen: int

    def pack(self) -> bytes:
        return struct.pack(">BHI", self.tag, self.id, self.plen)


@dataclass
class MessageMixin(Protocol):
    tag: ClassVar[MsgType]

    @abstractmethod
    def _sciffi_pack(self) -> bytes:
        return b""

    def header(self, msgid: int = 0, plen: int = 0) -> MessageHeader:
        return MessageHeader(tag=self.tag, id=msgid, plen=plen)

    def pack(self, msgid: int = 0) -> bytes:
        payload = self._sciffi_pack()
        return b"".join(
            (
                self.header(msgid=msgid, plen=len(payload)).pack(),
                payload,
            )
        )


@dataclass
class HandshakeMessage(MessageMixin):
    version: int
    tag: ClassVar[MsgType] = MsgType.HANDSHAKE

    @override
    def _sciffi_pack(self) -> bytes:
        return struct.pack(">H", self.version)


@dataclass
class ResponseMessage(MessageMixin):
    code: int
    data: str
    tag: ClassVar[MsgType] = MsgType.RESPONSE

    @override
    def _sciffi_pack(self) -> bytes:
        return struct.pack(">B", self.code) + self.data.encode()


@dataclass
class GetRegisterMessage(MessageMixin):
    type: int
    name: str
    tag: ClassVar[MsgType] = MsgType.GETREGISTER

    @override
    def _sciffi_pack(self) -> bytes:
        return struct.pack(">B", self.type) + self.name.encode()


@dataclass
class PutRegisterMessage(MessageMixin):
    type: int
    name: str
    data: str
    tag: ClassVar[MsgType] = MsgType.PUTREGISTER

    @override
    def _sciffi_pack(self) -> bytes:
        return b"".join(
            (
                struct.pack(">B", self.type),
                self.name.encode(),
                b"\x00",
                self.data.encode(),
            )
        )


@dataclass
class WriteMessage(MessageMixin):
    data: str
    tag: ClassVar[MsgType] = MsgType.WRITE

    @override
    def _sciffi_pack(self) -> bytes:
        return self.data.encode()


@dataclass
class LogMessage(MessageMixin):
    level: int
    message: str
    tag: ClassVar[MsgType] = MsgType.LOG

    @override
    def _sciffi_pack(self) -> bytes:
        return b"".join(
            (
                struct.pack(">B", self.level),
                b"\x00",
                self.message.encode(),
            )
        )


@dataclass
class CloseMessage(MessageMixin):
    tag: ClassVar[MsgType] = MsgType.CLOSE

    def _sciffi_pack(self) -> bytes:
        return super()._sciffi_pack()


type Payload = (
    HandshakeMessage
    | ResponseMessage
    | GetRegisterMessage
    | PutRegisterMessage
    | WriteMessage
    | LogMessage
    | CloseMessage
)
