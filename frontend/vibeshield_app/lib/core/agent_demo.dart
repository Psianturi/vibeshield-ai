import 'dart:convert';

import 'package:web3dart/web3dart.dart';
import 'package:web3dart/crypto.dart';

class AgentDemoConfig {
  final int? chainId;
  final String registry;
  final String router;
  final String wbnb;
  final String musdt;
  final BigInt? creationFeeWei;
  final String? configError;

  const AgentDemoConfig({
    required this.chainId,
    required this.registry,
    required this.router,
    required this.wbnb,
    required this.musdt,
    required this.creationFeeWei,
    this.configError,
  });

  factory AgentDemoConfig.fromJson(Map<String, dynamic> json) {
    BigInt? fee;
    final rawFee = json['creationFeeWei'];
    if (rawFee != null) {
      final s = rawFee.toString().trim();
      if (s.isNotEmpty) {
        fee = BigInt.tryParse(s);
      }
    }

    return AgentDemoConfig(
      chainId: json['chainId'] is num ? (json['chainId'] as num).toInt() : null,
      registry: (json['registry'] ?? '').toString(),
      router: (json['router'] ?? '').toString(),
      wbnb: (json['wbnb'] ?? '').toString(),
      musdt: (json['musdt'] ?? '').toString(),
      creationFeeWei: fee,
      configError: json['configError']?.toString(),
    );
  }
}

class AgentDemoTxBuilder {
  static const _registryAbi = [
    {
      'inputs': [
        {'internalType': 'uint8', 'name': 'strategy', 'type': 'uint8'}
      ],
      'name': 'spawnAgent',
      'outputs': [],
      'stateMutability': 'payable',
      'type': 'function'
    }
  ];

  static const _erc20Abi = [
    {
      'inputs': [
        {'internalType': 'address', 'name': 'spender', 'type': 'address'},
        {'internalType': 'uint256', 'name': 'amount', 'type': 'uint256'}
      ],
      'name': 'approve',
      'outputs': [
        {'internalType': 'bool', 'name': '', 'type': 'bool'}
      ],
      'stateMutability': 'nonpayable',
      'type': 'function'
    }
  ];

  static String spawnAgentData({required int strategy}) {
    final abi =
        ContractAbi.fromJson(jsonEncode(_registryAbi), 'VibeShieldRegistry');
    final contract = DeployedContract(abi,
        EthereumAddress.fromHex('0x0000000000000000000000000000000000000000'));
    final fn = contract.function('spawnAgent');
    final bytes = fn.encodeCall([BigInt.from(strategy)]);
    return bytesToHex(bytes, include0x: true);
  }

  static String approveData({required String spender, required BigInt amount}) {
    final abi = ContractAbi.fromJson(jsonEncode(_erc20Abi), 'ERC20');
    final contract = DeployedContract(abi,
        EthereumAddress.fromHex('0x0000000000000000000000000000000000000000'));
    final fn = contract.function('approve');
    final bytes = fn.encodeCall([EthereumAddress.fromHex(spender), amount]);
    return bytesToHex(bytes, include0x: true);
  }

  static BigInt maxUint256() {
    return (BigInt.one << 256) - BigInt.one;
  }

  static String toHexQuantity(BigInt v) {
    if (v == BigInt.zero) return '0x0';
    return '0x${v.toRadixString(16)}';
  }
}
