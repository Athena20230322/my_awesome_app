import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:pointycastle/export.dart' as pc;
import 'package:asn1lib/asn1lib.dart';
import 'dart:io'; // 用於建立 mTLS 連線
import 'package:flutter/services.dart' show rootBundle; // 用於讀取 assets
import 'package:http/io_client.dart'; // 用於建立 mTLS Client
import 'package:shared_preferences/shared_preferences.dart'; // 用於儲存資料

// --- 基底加密與工具類別 (維持不變) ---
class _CryptoUtils {
  static String encryptAES_CBC_256(String plainText, String key, String iv) {
    final keyUtf8 = utf8.encode(key);
    final ivUtf8 = utf8.encode(iv);
    final encrypter = encrypt.Encrypter(encrypt.AES(encrypt.Key(Uint8List.fromList(keyUtf8)), mode: encrypt.AESMode.cbc));
    final encrypted = encrypter.encrypt(plainText, iv: encrypt.IV(Uint8List.fromList(ivUtf8)));
    return encrypted.base64;
  }

  static String decryptAES_CBC_256(String encryptedBase64, String key, String iv) {
    final keyUtf8 = utf8.encode(key);
    final ivUtf8 = utf8.encode(iv);
    final encrypter = encrypt.Encrypter(encrypt.AES(encrypt.Key(Uint8List.fromList(keyUtf8)), mode: encrypt.AESMode.cbc));
    final decrypted = encrypter.decrypt(encrypt.Encrypted.fromBase64(encryptedBase64), iv: encrypt.IV(Uint8List.fromList(ivUtf8)));
    return decrypted;
  }

  static String signData(String dataToSign, String privateKeyPem) {
    final privateKey = _parsePrivateKeyFromPem(privateKeyPem);
    final signer = pc.RSASigner(pc.SHA256Digest(), '0609608648016503040201');
    signer.init(true, pc.PrivateKeyParameter<pc.RSAPrivateKey>(privateKey));
    final signature = signer.generateSignature(Uint8List.fromList(utf8.encode(dataToSign)));
    return base64.encode(signature.bytes);
  }

  static pc.RSAPrivateKey _parsePrivateKeyFromPem(String pem) {
    final cleanPem = pem.replaceAll('-----BEGIN PRIVATE KEY-----', '').replaceAll('-----END PRIVATE KEY-----', '').replaceAll(RegExp(r'\s'), '');
    final bytes = base64.decode(cleanPem);
    final asn1Parser = ASN1Parser(bytes);
    final topLevelSeq = asn1Parser.nextObject() as ASN1Sequence;
    ASN1Sequence innerSeq;
    final privateKeyOctetString = topLevelSeq.elements.firstWhere(
          (element) => element is ASN1OctetString,
      orElse: () => ASN1OctetString(Uint8List(0)),
    ) as ASN1OctetString;
    if (privateKeyOctetString.valueBytes().isNotEmpty) {
      final parser = ASN1Parser(privateKeyOctetString.valueBytes());
      innerSeq = parser.nextObject() as ASN1Sequence;
    } else {
      innerSeq = topLevelSeq;
    }
    final modulus = (innerSeq.elements[1] as ASN1Integer).valueAsBigInteger;
    final privateExponent = (innerSeq.elements[3] as ASN1Integer).valueAsBigInteger;
    final p = (innerSeq.elements[4] as ASN1Integer).valueAsBigInteger;
    final q = (innerSeq.elements[5] as ASN1Integer).valueAsBigInteger;
    return pc.RSAPrivateKey(modulus, privateExponent, p, q);
  }

  static Map<String, String> getCurrentTime() {
    final now = DateTime.now();
    return {
      'tradeNo': 'Sample${DateFormat('yyyyMMddHHmmss').format(now)}',
      'tradeDate': DateFormat('yyyy/MM/dd HH:mm:ss').format(now),
    };
  }
}

// --- 處理「現金儲值」、「反掃付款」與「反掃退款」的服務 ---
class GeneralApiService {
  static const String _aesKey = "VhoGVCInVF2UJ1cQBVZCF48lGUVIoCng";
  static const String _aesIV = "z3P4Se8qTFE0F1xI";
  static const String _encKeyId = "288768";
  static const String _privateKey = '''
-----BEGIN PRIVATE KEY-----
MIIEowIBAAKCAQEA0hXyO7E10c4WR/S1XUFUyvlLS8wX/3RoL9nE4kwWJC+nTy8A
FSVBgNz2KPnv3If+q8lG3bqq6TCiBmZxP33hbQH1H/cZPHag644nHlHc0/ZSunXB
92jprH4xf96wfev12wqrMbCnYKytInEJnuHN+n3eq0LuyQ/WRcPVROJWxYFUO+uG
LbFohtmppb0f/cSKOr0hVP15qZAEVSQwYHhu1CJAI/XoRLkZd87A2KHzvVJ2qkbj
RbzXemRToE0v3GrWoUoBIMW3cJxgKieMW/HhQHfnz8njTf4nYlA4OSi2U43OA3Z9
T+9gB5I8FvfOokt/LfhvO5q/l7QWB+yaX2hvuQIDAQABAoIBAAd57PYnWws1mpDi
ej7Ql6AmiYGvyG3YmmmThiBohUQx5vIYMdhOzFs14dO4+0p9k3hRECLNZQ4p4yY3
qJGSHP7YWj0SOdVvQlBHrYg0cReg9TY6ARZZJzGyhvfuOJkul7/9C/UXfIlh88Jd
Q/KhxgcDSjSNi/pfRCiU7MbICD78h/pCS1zIWHaICZ2aL5rV2o5JwCcvDP8p3F+L
FW/5u5kK0D0Pd29FXhf5MKHC4Mgrn2I44Uyhdud2Mf7wdvYvvcv2Nzn/EvM7uYZp
kEyC3Y1Ow037fZjO3pVCVRt8Mbo4B75ORqXQnr1SbKXWXM/unUEIfMhsBRhx/diD
CO8xyiECgYEA8UXIvYWREf+EN5EysmaHcv1jEUgFym8xUiASwwAv+LE9jQJSBiVy
m13rIGs01k1RN9z3/RVc+0BETTy9qEsUzwX9oTxgqlRk8R3TK7YEg6G/W/7D5DDM
9bS/ncU7PlKA/FaEasHCfjs0IY5yJZFYrcA2QvvCl1X1NUZ4Hyumk1ECgYEA3ujT
DbDNaSy/++4W/Ljp5pIVmmO27jy30kv1d3fPG6HRtPvbwRyUk/Y9PQpVpd7Sx/+G
N+95Z3/zy1IHrbHN5SxE+OGzLrgzgj32EOU+ZJk5uj9qNBkNXh5prcOcjGcMcGL9
OAC2oaWaOxrWin3fAzDsCoGrlzSzkVANnBRB6+kCgYEA2EaA0nq3dxW/9HugoVDN
HCPNOUGBh1wzLvX3O3ughOKEVTF+S2ooGOOQkGfpXizCoDvgxKnwxnxufXn0XLao
+YbaOz0/PZAXSBg/IlCwLTrBqXpvKM8h+yLCHXAeUhhs7UW0v2neqX7ylR32bnyir
GW/fj3lyfjQrKf1p6NeV3ECgYB2X+fspk5/Iu+VJxv3+27jLgLg6UE1BPONbx8c
4XgPsYB+/xz1UWsppCNjLgDLxCflY7HwNHEhYJakC5zeRcUUhcze6mTQU6uu556r
3EGlBKXeXVzV69Pofngaef3Bpdu6NydHvUE/WIUuDBOQmkV7GVjQP4pTEv6lFYEU
uMFFOQKBgHfINuaiIlITl/u59LPrvhTZoq6qg7N/3wVeAjYvbpv+b2cFgvOMQAr+
S8eCDzijy2z4MENBTr/q6mkKe4NHFGtodP+bjSYEG+GnBEG+EUpAx3Wh/BL2f/sI
iSOH9ODB6B847F+apa0OTawmslgGna9/985egGMto9g16EQ4ib1M
-----END PRIVATE KEY-----
''';

  /// :sparkles: **1. 修改底層請求函式，讓它只回傳解密後的純 JSON 字串**
  ///    錯誤處理改為拋出例外
  Future<String> _postRequest(Uri url, String jsonDataString) async {
    final encdata = _CryptoUtils.encryptAES_CBC_256(jsonDataString, _aesKey, _aesIV);
    final signature = _CryptoUtils.signData(encdata, _privateKey);
    try {
      final response = await http.post(
        url,
        headers: {
          'X-iCP-EncKeyID': _encKeyId,
          'X-iCP-Signature': signature,
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: {'EncData': encdata},
      );
      if (response.statusCode == 200) {
        final responseBody = json.decode(response.body);
        // 直接回傳解密後的原始 JSON 字串
        return _CryptoUtils.decryptAES_CBC_256(responseBody['EncData'], _aesKey, _aesIV);
      } else {
        // 網路請求失敗，拋出例外
        throw Exception("請求失敗：\n狀態碼: ${response.statusCode}\n回應: ${response.body}");
      }
    } catch (e) {
      // 捕捉其他所有可能的錯誤 (如網路中斷)
      throw Exception("請求時發生無法預期的錯誤: $e");
    }
  }

  /// :sparkles: **2. 修改付款函式，以處理純 JSON 並儲存資料**
  Future<String> performPayment({required String txAmt, required String buyerId}) async {
    final timeInfo = _CryptoUtils.getCurrentTime();
    final data = {
      "PlatformID": "10000266", "MerchantID": "10000266", "Ccy":"TWD", "TxAmt": "36",
      "NonRedeemAmt":"", "NonPointAmt":"", "StoreId":"217477", "StoreName": "見晴",
      "PosNo":"01", "OPSeq": timeInfo['tradeNo'], "OPTime": timeInfo['tradeDate'],
      "ReceiptNo":"", "ReceiptReriod":"", "TaxID":"", "CorpID":"22555003",
      "Vehicle":"", "Donate":"", "ItemAmt": "36", "UtilityAmt":"", "CommAmt":"",
      "ExceptAmt1":"", "ExceptAmt2":"", "BonusType":"ByWallet", "BonusCategory":"",
      "BonusID":"", "PaymentNo": "038", "Remark": "123456", "ReceiptPrint":"N",
      "Itemlist": [{}], "BuyerID": buyerId
    };
    try {
      // 呼叫重構後的 _postRequest
      final rawDecryptedJson = await _postRequest(
        Uri.parse('https://icp-payment-stage.icashpay.com.tw/api/V2/Payment/Pos/SETPay'),
        json.encode(data),
      );
      // 解析可靠的純 JSON
      final decodedResponse = json.decode(rawDecryptedJson);
      // 如果交易成功 (RtnCode 是 '0000')，就儲存退款需要的資料
      /// :sparkles: **唯一的修改點在這裡**
      ///    將判斷條件從 'RtnCode' 改為 'ChannelStatusCode'
      if (decodedResponse['ChannelStatusCode'] == '0000') {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('refund_op_seq', decodedResponse['OPSeq']);
        await prefs.setString('refund_bank_seq', decodedResponse['BankSeq']);
        await prefs.setString('refund_buyer_id', buyerId);
        debugPrint(':white_check_mark: 退款資訊已成功儲存！'); // 加上日誌方便除錯
      } else {
        debugPrint(':warning: 交易未完全成功，未儲存退款資訊。ChannelStatusCode: ${decodedResponse['ChannelStatusCode']}');
      }
      const jsonEncoder = JsonEncoder.withIndent('  ');
      final prettyJson = jsonEncoder.convert(decodedResponse);
      return "請求成功！\n解密後的回應：\n$prettyJson";
    } catch (e) {
      return e.toString();
    }
  }

  /// :sparkles: **3. 修改退款函式，以處理純 JSON**
  Future<String> performRefund({ required String opSeq, required String bankSeq, required String buyerId, }) async {
    final timeInfo = _CryptoUtils.getCurrentTime();
    final data = {
      "OPSeq": opSeq, "BankSeq": bankSeq, "TxAmt": "36", "OPRefundSeq": bankSeq,
      "OPRefundTime": timeInfo['tradeDate'], "StoreId": "217477", "StoreName": "見晴",
      "PosNo": "01", "CorpID": "22555003", "Remark": "123456", "BuyerID": buyerId,
    };
    try {
      final rawDecryptedJson = await _postRequest(
        Uri.parse('https://icp-payment-stage.icashpay.com.tw/api/V2/Payment/Pos/SETPayRefund'),
        json.encode(data),
      );
      // 格式化成功訊息並回傳給 UI
      const jsonEncoder = JsonEncoder.withIndent('  ');
      final prettyJson = jsonEncoder.convert(json.decode(rawDecryptedJson));
      return "請求成功！\n解密後的回應：\n$prettyJson";
    } catch (e) {
      return e.toString();
    }
  }

  // 其他函式 (如 performTopUp) 也應遵循此模式，此處為簡潔省略，但建議一併修改
  Future<String> performTopUp({required String topUpAmt, required String buyerId}) async {
    final timeInfo = _CryptoUtils.getCurrentTime();
    final data = { "PlatformID": "10000266", "MerchantID": "10000266", "Ccy": "TWD", "TopUpAmt": topUpAmt, "OPSeq": timeInfo['tradeNo'], "StoreId": "982351", "StoreName": "鑫和睦", "PosNo": "01", "OPTime": timeInfo['tradeDate'], "CorpID": "22555003", "PaymentNo": "038", "Remark": "123456", "Itemlist": [{}], "BuyerID": buyerId, };
    try {
      final rawDecryptedJson = await _postRequest(
        Uri.parse('https://icp-payment-stage.icashpay.com.tw/api/V2/Payment/Pos/SETTopUp'),
        json.encode(data),
      );
      const jsonEncoder = JsonEncoder.withIndent('  ');
      final prettyJson = jsonEncoder.convert(json.decode(rawDecryptedJson));
      return "請求成功！\n解密後的回應：\n$prettyJson";
    } catch (e) {
      return e.toString();
    }
  }
}

// --- 處理「康是美」相關的服務 (維持不變) ---
class CosmedApiService {
  // --- 常數 (與 JS 檔案一致，不需變更) ---
  static const String _aesKey = "xtzXnXnjDkhVWXNZlPJ2gMGAElKF28Kw";
  static const String _aesIV = "IeAzH3aBMlD5pvai";
  static const String _encKeyId = "274676";
  static const String _platformId = "10536635";
  static const String _merchantId = "10536635";
  static const String _privateKey = '''
-----BEGIN PRIVATE KEY-----
MIIEogIBAAKCAQEAyScTCR4BQ17b2UP33jhPcdcKQfWyWxk5xoYsxw7+xoWsc6e6
KkxqQYY2BMZoMTy/t7Ko8sZnMLDYgaANlEnsDGidy/XoTbXLKNMPXiw9xsCsuQq5
DoGlNimu5uvRgTLWsJqb34UBl5lOCHmlvHvdLzw4fO/zlMuSf4pBSFmwVFytJxuN
gbXIhZyuVoWiFNR0SIzmouclyHjANaBnRgrXA/KXdvz1CjbCMlZz17L8n6POid9n
MvGfUdGfkKxxooYSNyND4lVcb41C9f+l2pXroG9owVwUUgzIa38fmIi3VzxNrJ4v
yYlNH5myMU2g7XKgOtWRxauP1jJS6xUEUVDwaQIDAQABAoIBACL6THEVaprQb+JD
02Is4IOnJP17P9xfcpB23GpwzRSwQeCKlfCtAP0L3XDPH2cQbTYANyigH2l0FvHT
ZwkWIZm2x1mkFRUOO5mJue5iOwvIjUBQAQXovVXBwcwdzXxt3q8u81PWyQQXgF4w
6QTxdPC1xAzVnMGO9JaA8AEot2SzuYckLjEGXrmUPLZCdJS5wbgwCwJuCxlHjWI0
sihRgWs5FbxiHrTTlepSacO0gl4/r2225fbTy4SeSQDf4mKmXX9cEHMSpyCwXKFs
QheXYXXvS/514Jomiou2ijTXywibxrv41KfdSK8NYCP85d0hGr0apvoomd7p3+cU
uKUrsxECgYEA+t1xFcx79B2s47hcD1cv/AAFt1mjGCqS2AQnDsiCAMEERfx2vudok
tUu+7abehWyo0NgkJqmG/xmY2LY/bMGP+OUnUhVDyPBQs4/Q6WIZmrIsIBYOoRzh
MIE7VPUwEcD1bMGC0oGrFO3TjNfEd/him9Z+9jK5JFMYXeYj4ZQusMCgYEAzUUif
EN0meksTZJo8qK5FPLbCdm7FAMEN/IrKacOO/ZROnFFtxpltezqon5mt2bxIaEbp
PSgpNc4bhFpWXX/O/VaW9xVy6YGG5x0YFLaGVpLpvZNdsf0/eIP8X75hDfftKIsk
htd9Frjk6zEu+989dipDQ5nRdUfekfNVTYC/WMCgYAOVs358wA6yd9x/L22WsNxY
gbxnfwGi5htJH+fBrL3nBDEd1PKQavmiKzw0lU8uzTExDsmyNAp1Vl84M+KYMtAp
599Bf9mqCKJ0QQot7N+NyhVfmCMp7l6oyRo9Fu6ydRcSKlVx9ttyjM2ExWiDev0X
70C+jdOrUdyYsWjnofKxQKBgE9WMzf4Em8SUk9BEVMGVaalHse14bqgV9cPwGL+8
F94mniOIzXb/AfOo/leBXFJVlV7IWYmLpjHnkXccO1kz9tqvxvWE0r8xkuRsuEv5
J/76FWFyPbp3eTqpOLgAqx5s/rq23M1JKE3J9KB6iABNjkHHn+vW3cAIoRukAwpL
gqlAoGAA3YT/HRvyTF4P+jUBoORsjYbK2/4kJ6Zi5hTRGbkFn9kmRIdJ0sflGrV7
y8Av/aE8KBTOqFETvBZQoW47X3BSjDYVqQhvlhtNjEV3cqd7PFLpF8JELh+MRDgv
RA+iwozDiG89+lS2cogP8smW6i2VYQsg1fLbQWW5J5lgBHLMq4=
-----END PRIVATE KEY-----''';

  Future<String> getPaymentUrl({required String totalAmount}) async {
    final timeInfo = _CryptoUtils.getCurrentTime();
    final data = {
      "PlatformID": _platformId,
      "MerchantID": _merchantId,
      "MerchantTradeNo": timeInfo['tradeNo'],
      "StoreID": "ICASH-001",
      "StoreName": "Cosmed",
      "MerchantTradeDate": timeInfo['tradeDate'],
      "TotalAmount": totalAmount,
      "ItemAmt": totalAmount,
      "UtilityAmt": "0",
      "ItemNonRedeemAmt": "0",
      "UtilityNonRedeemAmt": "0",
      "NonPointAmt": "0",
      "Item": [{"ItemNo": "001", "ItemName": "測試商品1", "Quantity": "1"}],
      "TradeMode": "2",
      "CallbackURL": "https://prod-21.japaneast.logic.azure.com/workflows/896a5a51348c488386c686c8e83293c8/triggers/ICPOB002/paths/invoke?api-version=2016-10-01&sp=%2Ftriggers%2FICPOB002%2Frun&sv=1.0&sig=81SiqqBYwWTplvxc3OSCCU6sk9oNT6nI4w5t9Z8v6j4",
      "RedirectURL": "https://shop.cosmed.com.tw",
    };

    final jsonDataString = json.encode(data);
    final encdata = _CryptoUtils.encryptAES_CBC_256(jsonDataString, _aesKey, _aesIV);
    final signature = _CryptoUtils.signData(encdata, _privateKey);

    final response = await http.post(
      Uri.parse('https://icp-payment-stage.icashpay.com.tw/api/V2/Payment/Cashier/GetPaymentURL'),
      headers: {
        'X-iCP-EncKeyID': _encKeyId,
        'X-iCP-Signature': signature,
        'Content-Type': 'application/x-www-form-urlencoded',
      },
      body: {'EncData': encdata},
    );

    if (response.statusCode == 200) {
      final responseBody = json.decode(response.body);
      if (responseBody.containsKey('EncData') && responseBody['EncData'] != null) {
        final decryptedData = _CryptoUtils.decryptAES_CBC_256(responseBody['EncData'], _aesKey, _aesIV);
        final parsedData = json.decode(decryptedData);

        if (parsedData['PaymentURL'] != null && (parsedData['PaymentURL'] as String).isNotEmpty) {
          return parsedData['PaymentURL'];
        } else {
          final jsonEncoder = JsonEncoder.withIndent('  ');
          final prettyError = jsonEncoder.convert(parsedData);
          throw Exception('API 回應錯誤 (未包含有效的 PaymentURL):\n$prettyError');
        }
      } else {
        throw Exception('API 回應格式錯誤: ${response.body}');
      }
    } else {
      throw Exception('HTTP 請求失敗 (狀態碼: ${response.statusCode})\n回應: ${response.body}');
    }
  }

  Future<String> performDeduction({required String totalAmount, required String barCode}) async {
    final timeInfo = _CryptoUtils.getCurrentTime();
    final data = {
      "PlatformID": _platformId,
      "MerchantID": _merchantId,
      "MerchantTradeNo": timeInfo['tradeNo'],
      "StoreID": "TM01",
      "StoreName": "COSMED實體門市扣款",
      "MerchantTradeDate": timeInfo['tradeDate'],
      "TotalAmount": totalAmount,
      "ItemAmt": totalAmount,
      "UtilityAmt": "0",
      "CommAmt": "0",
      "ItemNonRedeemAmt": "0",
      "UtilityNonRedeemAmt": "0",
      "CommNonRedeemAmt": "0",
      "NonPointAmt": "0",
      "Item": [
        {"ItemNo": "001", "ItemName": "測試商品1", "Quantity": "1"},
        {"ItemNo": "002", "ItemName": "測試商品2", "Quantity": "1"},
      ],
      "BarCode": barCode,
    };
    final jsonDataString = json.encode(data);
    final encdataForBody = _CryptoUtils.encryptAES_CBC_256(jsonDataString, _aesKey, _aesIV);
    final signature = _CryptoUtils.signData(encdataForBody, _privateKey);
    final response = await http.post(
      Uri.parse('https://icp-payment-stage.icashpay.com.tw/api/V2/Payment/Pos/DeductICPOF'),
      headers: {
        'X-iCP-EncKeyID': _encKeyId,
        'X-iCP-Signature': signature,
        'Content-Type': 'application/x-www-form-urlencoded',
      },
      body: {'EncData': encdataForBody},
    );
    if (response.statusCode == 200) {
      final responseBody = json.decode(response.body);
      if (responseBody.containsKey('EncData') && responseBody['EncData'] != null) {
        final decryptedData = _CryptoUtils.decryptAES_CBC_256(responseBody['EncData'], _aesKey, _aesIV);
        const jsonEncoder = JsonEncoder.withIndent('  ');
        final prettyPrintedJson = jsonEncoder.convert(json.decode(decryptedData));
        return "請求成功！\n解密後的回應：\n$prettyPrintedJson";
      } else {
        return "請求失敗，API 回應：\n${response.body}";
      }
    } else {
      return "請求失敗：\n狀態碼: ${response.statusCode}\n回應: ${response.body}";
    }
  }
}

// --- 處理「UAT 現金儲值」的服務 (維持不變) ---
class UatGeneralApiService {
  static const String _aesKey = "wetEi4zKeJTDLcXCvqrDduAThvoeUudd";
  static const String _aesIV = "zlHw6q30q2qmWlzD";
  static const String _encKeyId = "117497";
  static const String _privateKey = '''
-----BEGIN PRIVATE KEY-----
MIIEowIBAAKCAQEAyTVkMuX3QXVAlISnNwRgWmVaOEkv/sq0P++q/gAeKBoqMh20
jCOO2tmGZ0XsBuvFToA8M1OwcLksGYJUeahd1oh3XerMr87+xS6L6+x3f+q7OJ2q
5LGyYXzF06z5ilfnH5oGuwtx5+okU03JkO4pYMXeJC3wHnPD6FwGd4IGdI83qTE8
IaE5vBbNshd/I3rLd9ETTNfmpll27gJYKbqDHFgtJoUwqXqo/VcHd2Wsrtma9tHM
3Yd+5fl63mccTlN3+OKQnGT2hXtQNa99H9LdiGae+Aq+z/Xsj1VJVbI5P1TTVy6W
AyGLQ2X5Kmakv+4LaB4+QDIxjecrCwYDCHlR3QIDAQABAoIBABgJE3rcCz0LyWbk
cMgq8uqhfFVIct4ML1uK4QF+GJwgQgWiFEkAT2aXwQ0xplgOTo/J1EcqWmOgzyKN
9dLhmLIRs7apn4Fp5/e8j3TjlsPWUb6Z4Qn4Ky+nlMcsPNP4m7Cj+OVboOP8DZJQ
8sDoHlPD1z05qpssp4yof5JDm0tNgS/GfOQJFC+bF9xmNtTfqD+T6zeidaARuy/u
PhSO2hG+NhNOjxcXwfIXihlGFxRNjTZtHmXDUgR5DXT4oJu0gNiz52QAX0tS4w+S
3xsRE+Y7rYVn1oDUSwMSWEycmGfur9Lv6CExrnHB13j26QaZ25MK902tyJlFQYCV
8esMO7ECgYEA6kU7Nqryrbld+lgsgg1Ks2nfqpYxnvGL6ITDYThphJdJhPTCITkU
FPkVo9KNks3B2K/Hj1fhb7Kr3i80D0pE0Yospj8ZjNt+hieB/mjQ9BmONvdrgxi1
fT/4Szwct631X5MJng9Nl23nHGgESV8xzIRs9K/IWUK9P/FArCSDAe0CgYEA298a
fAyg643Pdpb9qTM9/uJXHNkHHNPU7g+7Z2/mdjC/XZBy03qK7EdfZLZ4r/WXZxxU
xwu0C7mAaezPxWZypR4jSSPn2yz0AUMtrVjZnDfZgGbtsynUt9OffgHhRXsRhQ94
Lf56W7DteH/TxNwGuOmkgbajC2CcjCMNG4pNUbECgYAhnaWNhqIkA4FUtupMDxQ1
AnAxzjN4lzh4OPTAMpQRjpPiHCzvD32uNL/CLihadGPob/C2xOl4Wa8HxsY1m3ac
irM1d8B20dgp7+lbVDcHj9M0V/R5b0Y7nr5GLW4BfVjEShkLMS71F7QeA176GErR
Cf+IbODWzhjR4BBjoymZUQKBgQDQ2b+ijaxdk7q5fvs8OXxuHDl7IXvsGhtsdm0g
994F7pAYJBmuX/yOK82lMN665aIHQ5YT7D391RrxgwxpCcNkrJf/5adbPfwZJuLA
gmFSToq/uQWY5ec1JkOdwdNl2Fzv853Isq0vY4RurZ1OpWGNTAIDZKTDLeYGB1Vw
D5MaQQKBgBOnuj4zP9rp3G4vqCPWWvk0wV9MYMEXFc96Nm84Tj+YW7x3pxTAXlV1
VSeu8jKmdM0HkjQXM1mXfUuJo5WSM1FI1lKAMjLe31fhgxgEA6l4vtikHWXP/4II
yiYBqKyNOnJVxll34qaiYA80SkOEFJxX8QvBgHtWf7x2IKyFthEr
-----END PRIVATE KEY-----
''';

  Future<String> performTopUp({required String topUpAmt, required String buyerId}) async {
    final timeInfo = _CryptoUtils.getCurrentTime();
    final data = { "PlatformID": "10000266", "MerchantID": "10000266", "Ccy": "TWD", "TopUpAmt": topUpAmt, "OPSeq": timeInfo['tradeNo'], "StoreId": "982351", "StoreName": "鑫和睦", "PosNo": "01", "OPTime": timeInfo['tradeDate'], "CorpID": "22555003", "PaymentNo": "038", "Remark": "123456", "Itemlist": [{}], "BuyerID": buyerId, };
    // 使用 UAT 的 URL
    return _postRequest(Uri.parse('https://icp-payment-preprod.icashpay.com.tw/api/V2/Payment/Pos/SETTopUp'), json.encode(data));
  }

  Future<String> _postRequest(Uri url, String jsonDataString) async {
    final encdata = _CryptoUtils.encryptAES_CBC_256(jsonDataString, _aesKey, _aesIV);
    final signature = _CryptoUtils.signData(encdata, _privateKey);
    final response = await http.post(url, headers: { 'X-iCP-EncKeyID': _encKeyId, 'X-iCP-Signature': signature, 'Content-Type': 'application/x-www-form-urlencoded', }, body: {'EncData': encdata},);
    if (response.statusCode == 200) {
      final responseBody = json.decode(response.body);
      final decryptedData = _CryptoUtils.decryptAES_CBC_256(responseBody['EncData'], _aesKey, _aesIV);
      return "請求成功！\n解密後的回應：\n$decryptedData";
    } else {
      return "請求失敗：\n狀態碼: ${response.statusCode}\n回應: ${response.body}";
    }
  }
}

// --- 處理「FISC QR Code 掃碼購物」的服務 ---
class FiscApiService {
  // --- 從 Node.js 範例中移植過來的設定 ---
  static const String _host = 'openapigw.fisc-test.com.tw';
  static const int _port = 443;
  static const String _path = '/openAPI/FiscQaAPI/v1.0.0/qrPurchase/IntIssMerchScanRequest';
  static const String _bankId = '392';
  static const String _keyId = 'ff1d7a7f-4ac1-47ff-9559-6a0b881964db';
  static const String _countryCode = '410';
  static const String _defaultTxnNo = '1000277'; // 起始值

  /// 讀取本地儲存的交易序號，並自動+1後回存
  Future<String> _getNextTxnNo() async {
    final prefs = await SharedPreferences.getInstance();
    // 從 shared_preferences 讀取上次的序號，若沒有則使用預設值
    final lastTxnNo = prefs.getString('fisc_txn_no') ?? _defaultTxnNo;

    // 將字串轉為數字，+1後再轉回字串
    final nextTxnNo = (int.parse(lastTxnNo) + 1).toString();

    // 將新的序號存回 shared_preferences
    await prefs.setString('fisc_txn_no', nextTxnNo);

    return nextTxnNo;
  }

  /// 建立一個帶有客戶端憑證的 mTLS HttpClient
  Future<http.Client> _createMTLSClient() async {
    // 1. 從 assets 讀取憑證和金鑰檔案
    final certBytes = utf8.encode(await rootBundle.loadString('assets/cert.pem'));
    final keyBytes = utf8.encode(await rootBundle.loadString('assets/key.pem'));
    final caBytes = utf8.encode(await rootBundle.loadString('assets/ca.pem'));

    // 2. 建立 SecurityContext
    final securityContext = SecurityContext(withTrustedRoots: true);
    // 載入客戶端憑證鏈
    securityContext.useCertificateChainBytes(certBytes);
    // 載入客戶端私鑰
    securityContext.usePrivateKeyBytes(keyBytes);
    // 設定要信任的伺服器 CA (可選，但建議)
    securityContext.setTrustedCertificatesBytes(caBytes);

    // 3. 建立 dart:io 的 HttpClient
    final httpClient = HttpClient(context: securityContext);

    // 4. (重要) 設定憑證驗證回呼
    // 這相當於 Node.js 中的 `rejectUnauthorized: false`
    // 在測試環境中，如果伺服器憑證是自簽的，這可以略過驗證
    // 在生產環境中，應設為 false 或移除此行
    httpClient.badCertificateCallback = (X509Certificate cert, String host, int port) => true;

    // 5. 將 dart:io 的 HttpClient 包裝成 http 套件可用的 IOClient
    return IOClient(httpClient);
  }

  /// 執行 QR Code 掃碼購物請求
  Future<String> performQrPurchase({required String buyerId, required String txAmt}) async {
    http.Client? client;
    try {
      // 建立 mTLS 客戶端
      client = await _createMTLSClient();

      // 準備請求的 body
      final requestBody = {
        "BankID": _bankId,
        "TxnNo": await _getNextTxnNo(),
        "TxnAmount": txAmt,
        "CountryCode": _countryCode,
        "BuyerID": buyerId,
      };

      final bodyString = json.encode(requestBody);

      // 準備請求的 headers
      final headers = {
        'Content-Type': 'application/json',
        'X-KeyId': _keyId,
      };

      // 建立請求的 URL
      final url = Uri.https(_host, _path);

      // 發送 POST 請求
      final response = await client.post(
        url,
        headers: headers,
        body: bodyString,
      );

      // 處理回應
      if (response.statusCode == 200) {
        // 美化 JSON 輸出
        const jsonEncoder = JsonEncoder.withIndent('  ');
        final prettyPrintedJson = jsonEncoder.convert(json.decode(response.body));
        return "請求成功！\n回應：\n$prettyPrintedJson";
      } else {
        return "請求失敗：\n狀態碼: ${response.statusCode}\n回應: ${response.body}";
      }
    } catch (e) {
      // 捕捉任何可能的錯誤
      return "請求時發生錯誤：\n$e";
    } finally {
      // 無論成功或失敗，都要關閉 client
      client?.close();
    }
  }
}

// --- :sparkles: 新增：處理「美廉社」相關的服務 ---
class SimpleMartApiService {
  // --- 常數 (從 simplemart.js 移植) ---
  static const String _aesKey = "fGZblcB5mqKaZODh2poRTafdFtsul14o";
  static const String _aesIV = "fs0uM1EcLRE6UeqQ";
  static const String _encKeyId = "202775";
  static const String _platformId = "10511196";
  static const String _merchantId = "10511196";
  static const String _privateKey = '''
-----BEGIN PRIVATE KEY-----
MIIEpAIBAAKCAQEA76IaEIWtFyEnUdRkdzNO1Z1Yc62TvwVlI4I3wlJKF9a3ml6j
H7IyBe4W9Utm0LhvU1LDZM/ccqJ8c78dYOGuwCpsi6HrLNRJ3INjCC3z5X7zlLDK
dIRkn9dI9/b8kIAPEWAePfCKIb9mlk4aFX1LjkhoghSa2r6S0VRRLalTHOvPlzIx
v1nde958VTERvB0FNY9kanIsXLvcY1tAeVNW0Oo/LJxsHpV89RqWWcIpbELZIIqI
y4JZSkOFl9quBqLUEM5b/VVJMZVZDG9Z046Kk5EM6tjOrJ5OHE/G+6f8N1PcmFWy
GHC+C0ppHLQWO1/IbGeWur4+Dja4Noo1kqTGDwIDAQABAoIBABr9KayuXuTJ00kI
P/pxjmbzrj3KZmdaFF6FRiy+Ijcrc96l2v8buD4/vFk10VIfpkt++PUWjhsLyYgr
Fa7O1uTbbQHlo3xB5UG55degKVCHKv2WUxmqvD8zuuBRR80p3HNAspdCS08VZK34
BOsNA2ChL21lzwe6Sq8wgmYUpIDkpwqy1A53py7RBbd4HsD/RQZVGPCclgw2NfgT
0NcATAPDXiFd41A02Avi3+YW0Q5uo9RlxMPxsNVGLvP0vxFLFFc3/BGJT4nWpW2f
hV931ygMcv86ioEot7190cbkPFuIph+/MVcM+eI5ZOtyVrFwsL/Wy/6X1AkO3KmB
W/ghyFECgYEA9kOq+S6KvkHiFDYMs1nMl4bE7wIICD2Dh4jtYd77izpsuyoMF8OA
khbv/KdE3dmRywLSoG6ST+X+glHcaySwh4oKwgXUh+xA4HX2euIwG6t9QK59i3Uw
LDu8khLS6GYlGozduJTJhYtiS7ES+frF7zYQ/2VXeYEBLaa2sQHd0PECgYEA+RtS
xwPoj/tHK5a6fFiRRejYgd591GSfgDy+xqYwLOH8xs0TjrTY2XpbjpIxNR/j64e6
m3a4V/7udC27Pdiv1JI4o+5+0N94t4oWGxPZCeKPIOP1yi2OIvTrlLO4isgUAxQr
OWi0iREXUa/vHmwCt5SWWweaNCu4G9vVP0CMBv8CgYBZIZS4K4g75EyXVBi0sUPD
dBvDBdEyalE4tO52Bea1Nag09br6vt/CAFtL7p6WTTDfcV4aguqh0HSVZluIy/a4
l9Xc849AwtmYZBmZ0FPpL+BdkMoPt5J/7/8IP5fmVVIIkgON0ww9MX2aN7TOlV0e
f0sXpO5MI8zxYO2ukyZdgQKBgQDGnD5XZopZoaKQ4lA1K/hHoOpeQSJZ4RA6kjQY
9g+a+WMsrf1V3mK2opO1DGInVRHHjCQAJ5u6rQs5neyX1tf5x8tZCKIbrtD0pSgS
1rRI6VXsh1REqiWVQWlC2jfcjsFF4yLDVvP6BKJvArLHsp5H+DQYx+ruhZz4uUFA
eRoryQKBgQC1NVpw/pbz56zEA8WYRqKX5ujx0UI/u1h78sB1zNYBCY4ed6cqAN5i
lgruFu6+AzJ5zVC+hJB9PGs0vWWj1dP7YWFE2ZjtGY6rBU0Zz7w5h6v2ITtDb3g6
l1IANgNAmBt23/JmkCUYUlb5YoFo9bD+sfo5QpMj51nn1o1TvezQtQ==
-----END PRIVATE KEY-----
''';

  /// 執行美廉社扣款請求
  Future<String> performDeduction({required String totalAmount, required String barCode}) async {
    final timeInfo = _CryptoUtils.getCurrentTime();
    final data = {
      "PlatformID": _platformId,
      "MerchantID": _merchantId,
      "MerchantTradeNo": timeInfo['tradeNo'],
      "StoreID": "TM01",
      "StoreName": "美廉社3DS",
      "MerchantTradeDate": timeInfo['tradeDate'],
      "TotalAmount": totalAmount,
      "ItemAmt": totalAmount,
      "UtilityAmt": "0",
      "CommAmt": "0",
      "ItemNonRedeemAmt": "0",
      "UtilityNonRedeemAmt": "0",
      "CommNonRedeemAmt": "0",
      "NonPointAmt": "0",
      "Item": [
        {"ItemNo": "001", "ItemName": "測試商品1", "Quantity": "1"},
        {"ItemNo": "002", "ItemName": "測試商品2", "Quantity": "1"},
      ],
      "BarCode": barCode,
    };

    final jsonDataString = json.encode(data);
    final encdata = _CryptoUtils.encryptAES_CBC_256(jsonDataString, _aesKey, _aesIV);
    final signature = _CryptoUtils.signData(encdata, _privateKey);

    try {
      final response = await http.post(
        Uri.parse('https://icp-payment-stage.icashpay.com.tw/api/V2/Payment/Pos/DeductICPOF'),
        headers: {
          'X-iCP-EncKeyID': _encKeyId,
          'X-iCP-Signature': signature,
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: {'EncData': encdata},
      );

      if (response.statusCode == 200) {
        final responseBody = json.decode(response.body);
        if (responseBody.containsKey('EncData') && responseBody['EncData'] != null) {
          final decryptedData = _CryptoUtils.decryptAES_CBC_256(responseBody['EncData'], _aesKey, _aesIV);
          const jsonEncoder = JsonEncoder.withIndent('  ');
          final prettyPrintedJson = jsonEncoder.convert(json.decode(decryptedData));

          // 為了與 Node.js 腳本的輸出完全一致，我們也顯示原始的回應
          return "原始回應：\n${response.body}\n\n請求成功！\n解密後的回應：\n$prettyPrintedJson";
        } else {
          // 如果沒有 EncData，直接顯示整個 Body
          return "請求成功，但回應不含加密資料：\n${response.body}";
        }
      } else {
        throw Exception("請求失敗：\n狀態碼: ${response.statusCode}\n回應: ${response.body}");
      }
    } catch (e) {
      throw Exception("請求時發生無法預期的錯誤: $e");
    }
  }
}

// --- :tada: 全新加入：處理「愛金卡褔利社」相關的服務 ---
class IcashWelfareApiService {
  // --- 常數 (從您的 .js 檔案移植) ---
  static const String _aesKey = "ONa3KRM6qFHj3C4uwQUm9VtUCyTrj5Rv";
  static const String _aesIV = "BgLn0JGKPt1iqkEg";
  static const String _encKeyId = "274426";
  static const String _platformId = "10510013";
  static const String _merchantId = "10510013";
  static const String _privateKey = '''
-----BEGIN PRIVATE KEY-----
MIIEpAIBAAKCAQEA53oCtwOsvIfUKTpatqCeKHsRk5OG0hNhrApKoD0OFExMDi03
w4JA+kIJAciHOwofBfvWuVwW3ysOfx0DUZrSgDjPkaET1+z7hgG3X2onbYPqZfFy
7RfkO504BieJUvvYpYSM/sV+XHkIgt3L6VmvBKJoc4k4ak7EaPoOKzU66CWcCf9w
mKyottARr2KWlXmGtu55So8jYoXbnQlm3AcqEufvHwcqKbtsg6MEJSDPspHXzntU
H49eg7qG3LzmM3glBEBJaFABshSf5NcWeuoNQ1zoAYQUBAcF/Zb2nRZq+zU7gKMI
xrPVDJjljOcKqNJd30+UGDwh9s0GmKf3I39gGwIDAQABAoIBAA+EHTR5WZXVoQIW
eEgvogpinX3/8JSaWfy3P+NX1F7F8n8sxsUjMQnVbVciQvZRKl0zUWRhaOMStskM
f9FziFKx/C/t1S+vIfkMmmcZ7YSoyAiHU8XSySi51CyNb+YRHaeSqATX5i16q3hi
N63vpgywekHsW8y8dOv4fwSkb8tpwU2NDkoHm/lv9k2isy6AlKV/ZWODXcbBhkfR
y8ShjLOuLrQp5Cjgf6XvtpES4nTlPtJ44d2EoAhzp/pOkb5mDVverpZ5B5H6uRBN
xYhEwxItOIVIimgqKAMeB23DUR6RbcqEVcoDFX493in/SR8B1lXVCQs/EJZ2dQX0
voZDYPECgYEA6Ifyjpj2ZzLIO8Cn+U/C+9A65bIb5z26oQ14xe3jOKJTBrOBjgTa
9KzQRZL9eZFiThR98UtjEzPK4sLFqutkGyWRuOVz8cfYPqQqZx62rJn7dbJa2ndn
kj/S2R6sxckBwtwpJF1aeQPJVBWeeECDO1V8T/rkQzY6yc3c5NpJgDMCgYEA/tbR
oH5KReI0uOCCgbJZwsgpw4+MZIVWU/LNUQLPMUuVhso92utSTlKE3D64i+4Ju/nC
ZH7Unf/TpOtfXX2WECsE5pLZYQhYwc/dWpGBNmqLMFAl69QI3EUTvqKOxeUSaJ7C
BKzlieCjfTG8W0M/uwD5njDM9AzKrVq+sHFPGHkCgYEAjHRhfOTEIT25WO5cB+m3
2ybCDLByzlCpBFMA2n2AvFrAT9HptYEVSKmB/CR3WxEIEiWqlS92HskwCZygjUc1
5nfg95ARYr/VzLCYtEUHDmbMTyF2Y3OwadSHZYJz1dw+ZhdZ+o8w8NvqphGQ8Q32
tsZCGoVvj3GYPQFOJiX8M6UCgYEAztv1gX/CLoP2I/QqO7lYX2I3dIT7g0Uw1CgN
Pas4IF2oXKeiGihWwTj+nAFVsFBjGnEcuJKzaCWX2REucidVPn6NFdUyGy+5TGm8
1p2x80f9ABSvE4UkRBjWdDJkDoNps/7aowztrkPoseFDchlejB+4gA5A8AHKK3mz
vGnduJECgYA4WPflwdwn9OI4o3dVTPM3heFoFgott3Z2vUbeW//yzRgN1E80J0Cv
q5+UyON2jcDH2KoUbwJ1+vVZkCRMs1fLUHYtnJGOkJ3PtUu5Sg/Un5q7bszevnPt
kMo1zc154vPzFar+TiglwXaJwJ/rGOR1WcpS3Xf2+gi8WwGgq8XZww==
-----END PRIVATE KEY-----
''';

  /// 執行愛金卡褔利社扣款請求
  Future<String> performDeduction({required String totalAmount, required String barCode}) async {
    final timeInfo = _CryptoUtils.getCurrentTime();
    final data = {
      "PlatformID": _platformId,
      "MerchantID": _merchantId,
      "MerchantTradeNo": timeInfo['tradeNo'],
      "StoreID": "TM01",
      "StoreName": "愛金卡褔利社九九號店3DS", // 使用指定的店家名稱
      "MerchantTradeDate": timeInfo['tradeDate'],
      "TotalAmount": totalAmount,
      "ItemAmt": totalAmount,
      "UtilityAmt": "0",
      "CommAmt": "0",
      "ItemNonRedeemAmt": "0",
      "UtilityNonRedeemAmt": "0",
      "CommNonRedeemAmt": "0",
      "NonPointAmt": "0",
      "Item": [
        {"ItemNo": "001", "ItemName": "測試商品1", "Quantity": "1"},
        {"ItemNo": "002", "ItemName": "測試商品2", "Quantity": "1"},
      ],
      "BarCode": barCode,
    };

    final jsonDataString = json.encode(data);
    final encdata = _CryptoUtils.encryptAES_CBC_256(jsonDataString, _aesKey, _aesIV);
    final signature = _CryptoUtils.signData(encdata, _privateKey);

    try {
      final response = await http.post(
        Uri.parse('https://icp-payment-stage.icashpay.com.tw/api/V2/Payment/Pos/DeductICPOF'),
        headers: {
          'X-iCP-EncKeyID': _encKeyId,
          'X-iCP-Signature': signature,
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: {'EncData': encdata},
      );

      if (response.statusCode == 200) {
        final responseBody = json.decode(response.body);
        if (responseBody.containsKey('EncData') && responseBody['EncData'] != null) {
          final decryptedData = _CryptoUtils.decryptAES_CBC_256(responseBody['EncData'], _aesKey, _aesIV);
          const jsonEncoder = JsonEncoder.withIndent('  ');
          final prettyPrintedJson = jsonEncoder.convert(json.decode(decryptedData));

          return "原始回應：\n${response.body}\n\n請求成功！\n解密後的回應：\n$prettyPrintedJson";
        } else {
          return "請求成功，但回應不含加密資料：\n${response.body}";
        }
      } else {
        throw Exception("請求失敗：\n狀態碼: ${response.statusCode}\n回應: ${response.body}");
      }
    } catch (e) {
      throw Exception("請求時發生無法預期的錯誤: $e");
    }
  }
}

// --- :books: 全新加入：處理「博客來」相關的服務 ---
class BooksApiService {
  // --- 常數 (建議依據博客來實際提供的金鑰進行修改，此處暫用與範例相同的結構) ---
  static const String _aesKey = "TYxdM1K7E3dXtiLvoA8x7umQvEpK0TRm";
  static const String _aesIV = "fi5FFFHNbtl52Tj4";
  static const String _encKeyId = "285460";
  static const String _platformId = "10510711";
  static const String _merchantId = "10510711";
  static const String _privateKey = '''
-----BEGIN PRIVATE KEY-----
MIIEogIBAAKCAQEArpvKBY7vlt4fcDG6pViNK9OqDZbi+1Vgn4RbXSqmlwdVDGnx1r99p4B64ga/bVAU/Q4vb5hXEmeCalczZl8K9BAcJJ0b8lKLst8OKSuRsCw6QGJIpDZJ5yI5vb0wwo2Cu24bKivrQ4vJwp9+zsrOMHkLv25/zfpGOcKN9x4nTSm673/ZPD9JqJD4bzv4djRBiUORD2RSbe8uYzrRuxOPN5RINah6/TV5cO4tjVM8syehXNd4Zv8C3lqjnrRaChcDwbiJOSLpG89ybNyynjMqOwSBhTO1goEFZxeqInREfBsscBvbLuSJsOd75XxUBzlg8bCucVGX8B4grA1pzKHhIwIDAQABAoIBAAwiwdDPFXHr8E1w92MEm5M/O+OD6DTFw1hy75KzIy7+EHgzaN6fIpGgyWmqRGXJmhvYf42HDg42aYcQln73/h/mer5EuSuHdzQwcqCD6bVP7aCJ9DiNmWdaJp88ZgYvpbV3OqYctVZVgeloAn1G9TvDPgDJIlLjoTvkfM9/JgYj0dMOanfS9t1jYORwz5R5CjLUdhauAPTpw5Piuvu7Fpz4G95PwGw/tH+wlQLEbLwYHwLqRM2hQJa8tSTYdrkEq2svOmT+VY2eZXpy57BSdZFDMgJyVkiX3uv98tl1zSuGmOZc4KoaQAz6Uk5XqeQhPFwOxDwAufrVhz+GKyT0YxECgYEA6fEiSG6VuZOfRqHP9t08k9HXKUHxmwvdH679qHFf/b2SuCvklzz/H0Jfix6EarBSQGOLXpUgOQ0+mVl9KRrdd75mWCh7ghREiPwMjF15c0NiOhmYApmnpxWYNvv5KNmt2mbBtmhsJJ8ClE7eIL66RMEt924Q9bDZMOqhJ1QSS3kCgYEAvxJ46BJRHk8n24OzmzzfsuT3V2I1pS2mWMxGqrHzu0mhv1YqP5W3Z/xAeXEk1l2bmOSLAbcAqnTr8Br5R+TckHYMlMFBekDQtZMv6Ox4agreSZN9+7HuW+jNBHc04FKwg5viGD5MNiDhESP3t4m9aR0OwPkxzCRusKNGdFCvDnsCgYA1nLA5nzYq2DzZJ/4L2fmm+qDvcJBY8ugS+bxh3NGdydMU5+I0EqN423If5Ld957iBzw5Cd7RxvqpI5Gw9fk2gwn6b13MuhUyLhA+wHz/U/W1GWVUvy1zTeqxudWJNTU19Tq04C0g1QEeMC2L2aB8x4H+TQ6MZWxT7E9ootCiZKQKBgD+VdRi9Z7MvYjMhi7ZgNo0AtvKkYve5zj6ElAuftl0f7qyOjvaj6um2vvnq1fhkJDBn9X43mQggapd3UndDSMbmEd+6xABb61hRR8M6VgPr4/cWFvmYR5rcSMVwqe7wdX8Gc+HfcVsd6+fZUUkJlDeTjOJYyuKFSTSM0RhJ9UdbAoGAagXhwXdtEpUKdI7Cit8TsXlklWpz2gHGnOPHV1XapUsa69aesuunIGiMWpLk6hUBQXOKNZ/DTjXrkRyLjZ6w0l9d6NKNNQhv3nfN4PN/9A/uPJnP5GUO+autVjcTSh1FdE7VrQhqmgUIvzql1VYgeoR3nRIhcOjbZfZsXn9Tl2A=
-----END PRIVATE KEY-----
''';

  /// 執行博客來扣款請求
  Future<String> performDeduction({required String totalAmount, required String barCode}) async {
    final timeInfo = _CryptoUtils.getCurrentTime();
    final data = {
      "PlatformID": _platformId,
      "MerchantID": _merchantId,
      "MerchantTradeNo": timeInfo['tradeNo'],
      "StoreID": "0",
      "StoreName": "博客來網路書店3DS", // 變更為博客來名稱
      "MerchantTradeDate": timeInfo['tradeDate'],
      "TotalAmount": totalAmount,
      "ItemAmt": totalAmount,
      "UtilityAmt": "0",
      "CommAmt": "0",
      "ItemNonRedeemAmt": "0",
      "UtilityNonRedeemAmt": "0",
      "CommNonRedeemAmt": "0",
      "NonPointAmt": "0",
      "Item": [
        {"ItemNo": "001", "ItemName": "測試書籍1", "Quantity": "1"},
        {"ItemNo": "002", "ItemName": "測試書籍2", "Quantity": "1"},
      ],
      "BarCode": barCode,
    };

    final jsonDataString = json.encode(data);
    final encdata = _CryptoUtils.encryptAES_CBC_256(jsonDataString, _aesKey, _aesIV);
    final signature = _CryptoUtils.signData(encdata, _privateKey);

    try {
      final response = await http.post(
        Uri.parse('https://icp-payment-stage.icashpay.com.tw/api/V2/Payment/Pos/DeductICPOF'),
        headers: {
          'X-iCP-EncKeyID': _encKeyId,
          'X-iCP-Signature': signature,
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: {'EncData': encdata},
      );

      if (response.statusCode == 200) {
        final responseBody = json.decode(response.body);
        if (responseBody.containsKey('EncData') && responseBody['EncData'] != null) {
          final decryptedData = _CryptoUtils.decryptAES_CBC_256(responseBody['EncData'], _aesKey, _aesIV);
          const jsonEncoder = JsonEncoder.withIndent('  ');
          final prettyPrintedJson = jsonEncoder.convert(json.decode(decryptedData));

          return "原始回應：\n${response.body}\n\n請求成功！\n解密後的回應：\n$prettyPrintedJson";
        } else {
          return "請求成功，但回應不含加密資料：\n${response.body}";
        }
      } else {
        throw Exception("請求失敗：\n狀態碼: ${response.statusCode}\n回應: ${response.body}");
      }
    } catch (e) {
      throw Exception("請求時發生無法預期的錯誤: $e");
    }
  }
}