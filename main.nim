import asyncnet
import asyncdispatch
import minecraft
import logging

var clients {.threadvar.}: seq[AsyncSocket]

proc processClient(client: AsyncSocket) {.async.} =
    let (ip, port) = client.getPeerAddr()
    echo "-----------------------------------------------------"
    log(LogLevel.Info, "inbound connection from: " & ip)
    discard await client.recv_varint()
    let packetId = await client.recv_varint()
    log(LogLevel.Info, "Packet ID: " & $packetId)

    case packetId:
    of 0:
        let protocolVersion = await client.recv_varint()
        let addressLength = await client.recv_varint()
        let address = await client.recv(addressLength)
        let port = await client.recv_short()
        let nextState = await client.recv_varint()
        log(LogLevel.Info, "protocol: " & $protocolVersion)
        log(LogLevel.Info, "address length: " & $addressLength)
        log(LogLevel.Info, "address: " & address)
        log(LogLevel.Info, "port: " & $port)
        log(LogLevel.Info, "next state: " & $nextState)

        case cast[ConnectionState](nextState):
        of Status:
            log(LogLevel.Info, "Sending MOTD...")
            var pingResponse: StatusResponse
            pingResponse.players.max = 420
            pingResponse.players.online = 69

            pingResponse.version.name = "pwnd"
            pingResponse.version.protocol = 767

            pingResponse.enforcesSecureChat = false
            
            # thats where the magic happens
            for i in 0..4020:
                pingResponse.description.text.add("§k§l\n")

            let packet: MCPacket = encodeStatusResponse(pingResponse)
            await client.send($packet)
        of Login:
            log(LogLevel.Info, "Someone tried to connect to the server, kicking...")
            var kickMessage: KickMessage
            kickMessage.text = "nuh uh"
            kickMessage.color = "red"
            let packet = encodeKickMessage(kickMessage)
            await client.send($packet)
    of 1:
        let ping: int64 = await client.recv_long()
        log(LogLevel.Info, "received ping: " & $ping)
        let pingPacket = encodePingResponse(ping)
        await client.send($pingPacket)
    of 122:
        log(LogLevel.Error, "Invalid packet")
    else:
        log(LogLevel.Error, "Unsupported packet ID: " & $packetId)

    client.close()
    echo "-----------------------------------------------------"

proc server() {.async.} =
    var port = 25565
    clients = @[]
    var serv = newAsyncSocket()
    serv.setSockOpt(OptReuseAddr, true)
    serv.bindAddr(Port(port))
    serv.listen()
    log(LogLevel.Info, "Server listening on port " & $port)

    while true:
        let client = await serv.accept()
        clients.add(client)

        asyncCheck processClient(client)

asyncCheck server()
runForever()