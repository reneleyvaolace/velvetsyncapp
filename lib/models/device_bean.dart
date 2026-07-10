import 'dart:convert';
import 'package:flutter/material.dart';

class ModeListBean {
  final int modeId;
  final int? special;
  final String? command;
  final int? intensity;
  final int? pattern;
  final int? direction;
  final int? speed;
  final String? name;
  final String? description;
  
  ModeListBean({
    required this.modeId,
    this.special,
    this.command,
    this.intensity,
    this.pattern,
    this.direction,
    this.speed,
    this.name,
    this.description,
  });
  
  factory ModeListBean.fromJson(Map<String, dynamic> json) {
    return ModeListBean(
      modeId: json['ModeId'] ?? json['modeId'] ?? 0,
      special: json['Special'] ?? json['special'],
      command: json['Command'] ?? json['command'],
      intensity: json['Intensity'] ?? json['intensity'],
      pattern: json['Pattern'] ?? json['pattern'],
      direction: json['Direction'] ?? json['direction'],
      speed: json['Speed'] ?? json['speed'],
      name: json['Name'] ?? json['name'],
      description: json['Description'] ?? json['description'],
    );
  }
  
  Map<String, dynamic> toJson() => {
    'ModeId': modeId,
    'Special': special,
    'Command': command,
    'Intensity': intensity,
    'Pattern': pattern,
    'Direction': direction,
    'Speed': speed,
    'Name': name,
    'Description': description,
  };
  
  bool get isSpecialMode => (special ?? 0) != 0;
}

class FuncObj {
  final bool isClassic;
  final bool isMusic;
  final bool isShake;
  final bool isVoice;
  final Map<String, dynamic>? config;
  
  FuncObj({
    required this.isClassic,
    required this.isMusic,
    required this.isShake,
    required this.isVoice,
    this.config,
  });
  
  factory FuncObj.fromJsonString(String jsonString) {
    try {
      final Map<String, dynamic> parsed = jsonDecode(jsonString);
      return FuncObj(
        isClassic: parsed.containsKey('classic') || parsed['classic'] == true,
        isMusic: parsed.containsKey('music') || parsed['music'] == true,
        isShake: parsed.containsKey('shake') || parsed['shake'] == true,
        isVoice: parsed.containsKey('voice') || parsed['voice'] == true,
        config: parsed,
      );
    } catch (_) {
      return FuncObj(isClassic: false, isMusic: false, isShake: false, isVoice: false);
    }
  }
  
  factory FuncObj.fromFunctionString(String funcString) {
    final parts = funcString.split(',');
    return FuncObj(
      isClassic: parts.contains('classic'),
      isMusic: parts.contains('music'),
      isShake: parts.contains('shake'),
      isVoice: parts.contains('voice'),
      config: {'raw': funcString},
    );
  }
}

class DeviceBean {
  final String id;
  final String name;
  final String barcode;
  final String bleName;
  final String broadcastPrefix;
  final int cateId;
  final FuncObj funcObj;
  final List<ClassicMode> classicModes;
  final bool isEncrypt;
  final bool isPrecise;
  final bool isPrivateProtocol;
  final String encryptCommand;
  
  DeviceBean({
    required this.id,
    required this.name,
    required this.barcode,
    required this.bleName,
    required this.broadcastPrefix,
    required this.cateId,
    required this.funcObj,
    required this.classicModes,
    required this.isEncrypt,
    required this.isPrecise,
    required this.isPrivateProtocol,
    required this.encryptCommand,
  });
  
  factory DeviceBean.fromJson(Map<String, dynamic> json) {
    final funcObjStr = json['funcObj'] ?? json['FuncObj'] ?? '{}';
    final funcObj = funcObjStr is String 
        ? FuncObj.fromJsonString(funcObjStr)
        : FuncObj(
            isClassic: false, 
            isMusic: false, 
            isShake: false, 
            isVoice: false
          );
    
    List<ClassicMode> modes = [];
    if (json['classicModes'] != null) {
      try {
        final decoded = jsonDecode(json['classicModes']);
        modes = (decoded as List)
            .map((e) => ClassicMode.fromJson(e as Map<String, dynamic>))
            .toList();
      } catch (_) {
        modes = [];
      }
    }
    
    return DeviceBean(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? json['DeviceTitle']?.toString() ?? 'Dispositivo',
      barcode: json['barcode']?.toString() ?? json['BarCode']?.toString() ?? '',
      bleName: json['bleName']?.toString() ?? json['BleName']?.toString() ?? '',
      broadcastPrefix: json['broadcastPrefix']?.toString() ?? json['BroadcastPrefix']?.toString() ?? '77 62 4d 53 45',
      cateId: json['cateId'] ?? json['CateId'] ?? 0,
      funcObj: funcObj,
      classicModes: modes,
      isEncrypt: json['isEncrypt'] ?? json['IsEncrypt'] ?? false,
      isPrecise: json['isPrecise'] ?? json['IsPrecise'] ?? false,
      isPrivateProtocol: json['isPrivateProtocol'] ?? json['IsPrivateProtocol'] ?? false,
      encryptCommand: json['encryptCommand']?.toString() ?? json['EncryptCommand']?.toString() ?? '',
    );
  }
}

class ClassicMode {
  final List<ModeListBean> groups;
  final String? modeType;
  
  ClassicMode({required this.groups, this.modeType});
  
  factory ClassicMode.fromJson(Map<String, dynamic> json) {
    List<ModeListBean> groups = [];
    if (json['Groups'] != null) {
      try {
        final decoded = jsonDecode(json['Groups']);
        groups = (decoded as List)
            .map((e) => ModeListBean.fromJson(e as Map<String, dynamic>))
            .toList();
      } catch (_) {
        groups = [];
      }
    }
    
    return ClassicMode(
      groups: groups,
      modeType: json['ModeType']?.toString() ?? json['modeType']?.toString(),
    );
  }
}