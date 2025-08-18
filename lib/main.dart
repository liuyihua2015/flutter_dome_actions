import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';

void main() {
  runApp(const MyApp());
}

/// TCP Server 封装
class TcpServer {
  ServerSocket? _server;
  final List<Socket> _clients = [];

  final int port;
  final Function(Socket)? onClientConnected;
  final Function(Socket)? onClientDisconnected;
  final Function(Socket, String)? onDataReceived;

  TcpServer({
    required this.port,
    this.onClientConnected,
    this.onClientDisconnected,
    this.onDataReceived,
  });

  Future<void> start() async {
    try {
      _server = await ServerSocket.bind("192.168.150.105", port);
      print('✅ TCP 服务已启动: 0.0.0.0:$port');

      _server!.listen((Socket client) {
        _clients.add(client);
        print('📡 新连接: ${client.remoteAddress.address}:${client.remotePort}');
        onClientConnected?.call(client);

        client.listen(
          (data) {
            String message = utf8.decode(data);
            print('📥 收到: $message');
            onDataReceived?.call(client, message);
          },
          onError: (err) {
            print('❌ 客户端错误: $err');
            _removeClient(client);
          },
          onDone: () {
            print('🔌 客户端断开');
            _removeClient(client);
          },
        );
      });
    } catch (e) {
      print('❌ 启动 TCP 服务失败: $e');
    }
  }

  void sendToClient(Socket client, String message) {
    client.add(utf8.encode(message));
  }

  void broadcast(String message) {
    for (var client in _clients) {
      sendToClient(client, message);
    }
  }

  Future<void> stop() async {
    for (var client in _clients) {
      await client.close();
    }
    _clients.clear();
    await _server?.close();
    print('🛑 TCP 服务已停止');
  }

  void _removeClient(Socket client) {
    _clients.remove(client);
    onClientDisconnected?.call(client);
    client.destroy();
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false, // 去掉右上角 DEBUG 标识
      title: 'TCP Server Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: 'Flutter TCP Server'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});
  final String title;
  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  late TcpServer _tcpServer;
  List<String> logs = [];

  @override
  void initState() {
    super.initState();
    _tcpServer = TcpServer(
      port: 19000,
      onClientConnected: (client) {
        _addLog("✅ 设备已连接: ${client.remoteAddress.address}");
      },
      onDataReceived: (client, data) {
        _addLog("📥 来自 ${client.remoteAddress.address}: $data");
      },
      onClientDisconnected: (client) {
        _addLog("🔌 设备已断开: ${client.remoteAddress.address}");
      },
    );
    _tcpServer.start();
    printLocalIps();
  }

  void printLocalIps() async {
    for (var interface in await NetworkInterface.list()) {
      for (var addr in interface.addresses) {
        if (addr.type == InternetAddressType.IPv4) {
          print('本机 IP: ${addr.address}');
        }
      }
    }
  }

  void _addLog(String log) {
    setState(() {
      logs.add(log);
    });
  }

  @override
  void dispose() {
    _tcpServer.stop();
    super.dispose();
  }

  void _sendMessage() {
    _tcpServer.broadcast("Hello from Flutter App!");
    _addLog("📤 已广播消息给所有设备");
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
      body: ListView.builder(
        itemCount: logs.length,
        itemBuilder: (context, index) {
          return ListTile(
            title: Text(logs[index]),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _sendMessage,
        tooltip: 'Send Message',
        child: const Icon(Icons.send),
      ),
    );
  }
}
