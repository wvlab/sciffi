import struct
import typing
from abc import abstractmethod
from dataclasses import dataclass
from enum import IntEnum
from typing import NamedTuple, Protocol, override


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
    @abstractmethod
    def _sciffi_pack(self) -> bytes:
        return b""

    def header(self, msgid: int, plen: int) -> MessageHeader:
        return header(msgid, plen, typing.cast(Payload, self))

    def pack(self, msgid: int) -> bytes:
        return pack(msgid, typing.cast(Payload, self))


@dataclass
class HandshakeMessage(MessageMixin):
    version: int

    @override
    def _sciffi_pack(self) -> bytes:
        return struct.pack(">H", self.version)


@dataclass
class ResponseMessage(MessageMixin):
    code: int
    data: str

    @override
    def _sciffi_pack(self) -> bytes:
        return struct.pack(">B", self.code) + self.data.encode()


@dataclass
class GetRegisterMessage(MessageMixin):
    type: int
    name: str

    @override
    def _sciffi_pack(self) -> bytes:
        return struct.pack(">B", self.type) + self.name.encode()


@dataclass
class PutRegisterMessage(MessageMixin):
    type: int
    name: str
    data: str

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

    @override
    def _sciffi_pack(self) -> bytes:
        return self.data.encode()


@dataclass
class LogMessage(MessageMixin):
    level: int
    message: str

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


def msgtype(p: Payload) -> MsgType:
    match p:
        case HandshakeMessage():
            return MsgType.HANDSHAKE
        case ResponseMessage():
            return MsgType.RESPONSE
        case GetRegisterMessage():
            return MsgType.GETREGISTER
        case PutRegisterMessage():
            return MsgType.PUTREGISTER
        case WriteMessage():
            return MsgType.WRITE
        case LogMessage():
            return MsgType.LOG
        case CloseMessage():
            return MsgType.CLOSE


def header(msgid: int, plen: int, msg: Payload) -> MessageHeader:
    return MessageHeader(tag=msgtype(msg), id=msgid, plen=plen)


def pack(msgid: int, msg: Payload) -> bytes:
    p = msg._sciffi_pack()
    return msg.header(msgid, len(p)).pack() + p
