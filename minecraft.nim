import bitops
import jsony
import strutils
import asyncnet
import asyncdispatch
import net

const SEGMENT_BITS = 0x7F
const SEGMENT_CONTINUATION_BIT = 0x80

type
    MCPacket* = object
        data*: seq[uint8] = @[]
    
    StatusResponse* = object
        version*: Version
        players*: Players
        description*: Description
        favicon*: string
        enforcesSecureChat*: bool
    Version* = object
        name*: string
        protocol*: int
    Players* = object
        max*: int
        online*: int
        sample*: seq[Sample]
    Sample* = object
        name*: string
        id*: string
    Description* = object
        text*: string

    KickMessage* = object
        text*: string
        color*: string

    ConnectionState* = enum
        Status = 1
        Login = 2

proc intToByte*(value: int): uint8 =
    return (value.uint8 and 0xFF)

proc strToBytes*(value: string): seq[uint8] =
    result = newSeq[uint8](value.len)
    for i in 0..value.len-1:
        result[i] = value[i].uint8
    return result

proc write_varint*(packet: var MCPacket, value: int) =
    var remaining: int = value
    for i in 0..4:
        if (bitand(remaining, (SEGMENT_BITS xor -1))) == 0:
            packet.data.add(remaining.uint8)
            return
        packet.data.add(intToByte(bitor(bitand(remaining, SEGMENT_BITS), SEGMENT_CONTINUATION_BIT)))
        remaining = remaining shr 7
    raise newException(Exception, "VarInt too big")

proc write_string*(packet: var MCPacket, value: string) =
    write_varint(packet, value.len)
    var bytes = strToBytes(value)

    for i in 0..bytes.len-1:
        packet.data.add(bytes[i])

proc write_short*(packet: var MCPacket, value: int16) =
    packet.data.add(intToByte((value shr 8) and 0xFF))
    packet.data.add(intToByte(value and 0xFF))

proc write_long*(packet: var MCPacket, value: int64) =
    var remaining: int = value
    for i in 0..5:
        if (bitand(remaining, cast[int64]((SEGMENT_BITS xor -1)))) == 0:
            packet.data.add(intToByte(remaining))
            return
        packet.data.add(bitor(bitand(remaining, SEGMENT_BITS), SEGMENT_CONTINUATION_BIT).uint8)
        remaining = remaining shr 7

proc write_bytes*(packet: var MCPacket, value: seq[uint8]) =
    for i in 0..value.len-1:
        packet.data.add(value[i])

proc `$`*(packet: MCPacket): string =
    result = newString(len(packet.data))
    copyMem(addr result[0], unsafeAddr packet.data[0], len(packet.data))

proc recv_varint*(socket: AsyncSocket): Future[int] {.async.} =
    var numRead: int = 0
    var read: int
    var result: int = 0

    while true:
        var r = await socket.recv(1)
        read = r[0].int32
        var value: int = read and SEGMENT_BITS
        result = result or (value shl (7 * numRead))

        inc numRead
        if numRead > 5:
            raise newException(Exception, "VarInt too big")
        if (read and SEGMENT_CONTINUATION_BIT) == 0:
            break

    return result

proc recv_short*(socket: AsyncSocket): Future[uint16] {.async.} =
    let data = await socket.recv(2)
    if data.len != 2:
        raise newException(ValueError, "Not enough data to read a short")

    result = (uint16(data[0].uint8) shl 8) or uint16(data[1].uint8)

proc recv_long*(socket: AsyncSocket): Future[int64] {.async.} =
    let data = await socket.recv(8)
    if data.len != 8:
        raise newException(ValueError, "Not enough data to read a long")
    
    result = 0'i64
    for i in 0..7:
        result = (result shl 8) or int64(data[i].uint8)

proc encodeStatusResponse*(ping: StatusResponse): MCPacket =
    var jsonPayload = ping.toJson()
    var packet: MCPacket
    packet.write_varint(0x00)
    packet.write_string(jsonPayload)

    result.write_varint(len(packet.data))
    result.write_bytes(packet.data)

proc encodeKickMessage*(message: KickMessage): MCPacket =
    var jsonPayload = message.toJson()
    var packet: MCPacket
    packet.write_varint(0x00)
    packet.write_string(jsonPayload)

    result.write_varint(len(packet.data))
    result.write_bytes(packet.data)

proc encodePingResponse*(ping: int64): MCPacket =
    var packet: MCPacket
    packet.write_varint(0x01)
    packet.write_long(ping)

    result.write_varint(len(packet.data))
    result.write_bytes(packet.data)