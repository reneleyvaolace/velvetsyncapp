import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:velvet_sync/devices/models/toy_model.dart';
import 'package:velvet_sync/models/device_bean.dart';

class DeviceController extends ChangeNotifier {
  ToyModel? _activeToy;
  DeviceBean? _deviceBean;
  
  ToyModel? get activeToy => _activeToy;
  DeviceBean? get deviceBean => _deviceBean;
  
  final Map<String, bool> _functions = {
    'isClassic': false,
    'isMusic': false,
    'isShake': false,
    'isVoice': false,
  };
  
  final List<ModeListBean> _availableModes = [];
  final List<ModeListBean> _specialModes = [];
  
  Map<String, bool> get functions => Map.unmodifiable(_functions);
  List<ModeListBean> get availableModes => List.unmodifiable(_availableModes);
  List<ModeListBean> get specialModes => List.unmodifiable(_specialModes);
  
  int? _cateId;
  int? get cateId => _cateId;
  
  void setActiveToy(ToyModel toy) {
    _activeToy = toy;
    _deviceBean = null;
    _availableModes.clear();
    _specialModes.clear();
    _functions.clear();
    _cateId = null;
    notifyListeners();
  }
  
  void setDeviceBean(DeviceBean bean) {
    _deviceBean = bean;
    _activeToy = _convertToDeviceToyModel(bean);
    _cateId = bean.cateId;
    _parseModes(bean);
    _parseFunctions(bean);
    notifyListeners();
  }
  
  ToyModel _convertToDeviceToyModel(DeviceBean bean) {
    return ToyModel(
      id: bean.barcode,
      name: bean.name,
      usageType: _inferUsageType(bean.cateId),
      targetAnatomy: _inferAnatomy(bean.cateId),
      stimulationType: _inferStimulationType(bean.cateId),
      motorLogic: bean.isPrecise ? 'Precise (0-255)' : 'Single Channel',
      imageUrl: '',
      qrCodeUrl: '',
      supportedFuncs: bean.funcObj.config?.toString() ?? '',
      isPrecise: bean.isPrecise,
      broadcastPrefix: bean.broadcastPrefix,
      bleProtocol: bean.isEncrypt 
          ? BleProtocolType.cryptBle 
          : (bean.bleName.toLowerCase().contains('omysky') ? BleProtocolType.ipao : BleProtocolType.classic),
      isPrivateProtocol: bean.isPrivateProtocol,
      encryptCommand: bean.encryptCommand,
    );
  }
  
  void _parseModes(DeviceBean bean) {
    _availableModes.clear();
    _specialModes.clear();
    
    for (final classicMode in bean.classicModes) {
      for (final mode in classicMode.groups) {
        if (mode.isSpecialMode) {
          _specialModes.add(mode);
        } else {
          _availableModes.add(mode);
        }
      }
    }
  }
  
  void _parseFunctions(DeviceBean bean) {
    _functions['isClassic'] = bean.funcObj.isClassic;
    _functions['isMusic'] = bean.funcObj.isMusic;
    _functions['isShake'] = bean.funcObj.isShake;
    _functions['isVoice'] = bean.funcObj.isVoice;
  }
  
  static String _inferUsageType(int? cateId) {
    switch (cateId) {
      case 1: return 'Insertable';
      case 2: return 'Wearable';
      case 3: return 'Dual';
      default: return 'Universal';
    }
  }
  
  static String _inferAnatomy(int? cateId) {
    switch (cateId) {
      case 1: return 'Vaginal';
      case 2: return 'Clitoral';
      case 3: return 'Anal';
      default: return 'Universal';
    }
  }
  
  static String _inferStimulationType(int? cateId) {
    switch (cateId) {
      case 1: return 'Vibración + Empuje';
      case 2: return 'Vibración';
      case 3: return 'Vibración + Succión';
      default: return 'Vibración';
    }
  }
  
  static Color getCateColor(int? cateId) {
    switch (cateId) {
      case 1: return const Color(0xFF2196F3);
      case 2: return const Color(0xFFDC143C);
      case 3: return const Color(0xFFFFC107);
      default: return const Color(0xFF9E9E9E);
    }
  }
  
  bool get hasDualChannel => _activeToy?.hasDualChannel ?? false;
  List<ModeListBean> get allModes => [..._availableModes, ..._specialModes];
  
  void clear() {
    _activeToy = null;
    _deviceBean = null;
    _availableModes.clear();
    _specialModes.clear();
    _functions.clear();
    _cateId = null;
  }
}

class DeviceInteraction {
  final ModeListBean mode;
  final bool isSpecial;
  final bool isActive;
  final VoidCallback? onTap;
  
  DeviceInteraction({
    required this.mode,
    required this.isSpecial,
    this.isActive = false,
    this.onTap,
  });
}