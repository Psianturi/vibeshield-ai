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

class AgentDemoStatus {
  final int? chainId;
  final String userAddress;
  final bool isAgentActive;
  final int strategy;
  final BigInt allowanceWei;
  final BigInt userWbnbWei;
  final BigInt backendWbnbWei;
  final String? statusError;

  const AgentDemoStatus({
    required this.chainId,
    required this.userAddress,
    required this.isAgentActive,
    required this.strategy,
    required this.allowanceWei,
    required this.userWbnbWei,
    required this.backendWbnbWei,
    this.statusError,
  });

  bool get hasApproval => allowanceWei > BigInt.zero;

  factory AgentDemoStatus.fromJson(Map<String, dynamic> json) {
    BigInt allowance = BigInt.zero;
    final rawAllowance = json['allowanceWei'];
    if (rawAllowance != null) {
      allowance = BigInt.tryParse(rawAllowance.toString().trim()) ?? BigInt.zero;
    }

    BigInt userWbnb = BigInt.zero;
    final rawUserWbnb = json['userWbnbWei'];
    if (rawUserWbnb != null) {
      userWbnb = BigInt.tryParse(rawUserWbnb.toString().trim()) ?? BigInt.zero;
    }

    BigInt backendWbnb = BigInt.zero;
    final rawBackendWbnb = json['backendWbnbWei'];
    if (rawBackendWbnb != null) {
      backendWbnb = BigInt.tryParse(rawBackendWbnb.toString().trim()) ?? BigInt.zero;
    }

    return AgentDemoStatus(
      chainId: json['chainId'] is num ? (json['chainId'] as num).toInt() : null,
      userAddress: (json['userAddress'] ?? '').toString(),
      isAgentActive: json['isAgentActive'] == true,
      strategy: json['strategy'] is num ? (json['strategy'] as num).toInt() : 0,
      allowanceWei: allowance,
      userWbnbWei: userWbnb,
      backendWbnbWei: backendWbnb,
      statusError: json['statusError']?.toString(),
    );
  }
}

class AgentDemoTopUpResult {
  final bool success;
  final String? txHash;
  final BigInt? amountWei;
  final String? error;

  const AgentDemoTopUpResult({
    required this.success,
    this.txHash,
    this.amountWei,
    this.error,
  });

  factory AgentDemoTopUpResult.fromJson(Map<String, dynamic> json) {
    BigInt? amount;
    final rawAmount = json['amountWei'];
    if (rawAmount != null) {
      amount = BigInt.tryParse(rawAmount.toString().trim());
    }

    return AgentDemoTopUpResult(
      success: json['success'] == true,
      txHash: json['txHash']?.toString(),
      amountWei: amount,
      error: json['error']?.toString(),
    );
  }
}

class AgentDemoContext {
  final String token;
  final String headline;
  final String severity;
  final int timestamp;
  final int expiresAt;
  final bool consumed;

  const AgentDemoContext({
    required this.token,
    required this.headline,
    required this.severity,
    required this.timestamp,
    required this.expiresAt,
    required this.consumed,
  });

  bool get isActive => !consumed && DateTime.now().millisecondsSinceEpoch < expiresAt;

  factory AgentDemoContext.fromJson(Map<String, dynamic> json) {
    return AgentDemoContext(
      token: (json['token'] ?? '').toString(),
      headline: (json['headline'] ?? '').toString(),
      severity: (json['severity'] ?? '').toString(),
      timestamp: json['timestamp'] is num ? (json['timestamp'] as num).toInt() : 0,
      expiresAt: json['expiresAt'] is num ? (json['expiresAt'] as num).toInt() : 0,
      consumed: json['consumed'] == true,
    );
  }
}

class AgentDemoInjectResult {
  final bool ok;
  final AgentDemoContext? context;
  final String? error;

  const AgentDemoInjectResult({
    required this.ok,
    this.context,
    this.error,
  });
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
