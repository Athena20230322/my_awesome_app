import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:pointycastle/export.dart' as pc;
import 'package:asn1lib/asn1lib.dart';

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

// --- 處理「現金儲值」和「反掃付款」的服務 (維持不變) ---
class GeneralApiService {
  static const String _aesKey = "VhoGVCInVF2UJ1cQBVZCF48lGUVIoCng";
  static const String _aesIV = "z3P4Se8qTFE0F1xI";
  static const String _encKeyId = "288768";
  static const String _privateKey = '''
-----BEGIN PRIVATE KEY-----
MIIEowIBAAKCAQEA0hXyO7E10c4WR/S1XUFUyvlLS8wX/3RoL9nE4kwWJC+nTy8AFSVBgNz2KPnv3If+q8lG3bqq6TCiBmZxP33hbQH1H/cZPHag644nHlHc0/ZSunXB92jprH4xf96wfev12wqrMbCnYKytInEJnuHN+n3eq0LuyQ/WRcPVROJWxYFUO+uGLbFohtmppb0f/cSKOr0hVP15qZAEVSQwYHhu1CJAI/XoRLkZd87A2KHzvVJ2qkbjRbzXemRToE0v3GrWoUoBIMW3cJxgKieMW/HhQHfnz8njTf4nYlA4OSi2U43OA3Z9T+9gB5I8FvfOokt/LfhvO5q/l7QWB+yaX2hvuQIDAQABAoIBAAd57PYnWws1mpDiej7Ql6AmiYGvyG3YmmmThiBohUQx5vIYMdhOzFs14dO4+0p9k3hRECLNZQ4p4yY3qJGSHP7YWj0SOdVvQlBHrYg0cReg9TY6ARZZJzGyhvfuOJkul7/9C/UXfIlh88JdQ/KhxgcDSjSNi/pfRCiU7MbICD78h/pCS1zIWHaICZ2aL5rV2o5JwCcvDP8p3F+LFW/5u5kK0D0Pd29FXhf5MKHC4Mgrn2I44Uyhdud2Mf7wdvYvvcv2Nzn/EvM7uYZpkEyC3Y1Ow037fZjO3pVCVRt8Mbo4B75ORqXQnr1SbKXWXM/unUEIfMhsBRhx/diDCO8xyiECgYEA8UXIvYWREf+EN5EysmaHcv1jEUgFym8xUiASwwAv+LE9jQJSBiVym13rIGs01k1RN9z3/RVc+0BETTy9qEsUzwX9oTxgqlRk8R3TK7YEg6G/W/7D5DDM9bS/ncU7PlKA/FaEasHCfjs0IY5yJZFYrcA2QvvCl1X1NUZ4Hyumk1ECgYEA3ujTDbDNaSy/++4W/Ljp5pIVmmO27jy30kv1d3fPG6HRtPvbwRyUk/Y9PQpVpd7Sx/+GN+95Z3/zy1IHrbHN5SxE+OGzLrgzgj32EOU+ZJk5uj9qNBkNXh5prcOcjGcMcGL9OAC2oaWaOxrWin3fAzDsCoGrlzSzkVANnBRB6+kCgYEA2EaA0nq3dxW/9HugoVDNHCPNOUGBh1wzLvX3O3ughOKEVTF+S2ooGOOQkGfpXizCoDvgxKnwxnxufXn0XLao+YbaOz0/PZAXSBg/IlCwLTrBqXpvKM8h+yLCHXAeUhhs7UW0v2neqX7ylR32bnyirGW/fj3lyfjQrKf1p6NeV3ECgYB2X+fspk5/Iu+VJxv3+27jLgLg6UE1BPONbx8c4XgPsYB+/xz1UWsppCNjLgDLxCflY7HwNHEhYJakC5zeRcUUhcze6mTQU6uu556r3EGlBKXeXVzV69Pofngaef3Bpdu6NydHvUE/WIUuDBOQmkV7GVjQP4pTEv6lFYEUuMFFOQKBgHfINuaiIlITl/u59LPrvhTZoq6qg7N/3wVeAjYvbpv+b2cFgvOMQAr+S8eCDzijy2z4MENBTr/q6mkKe4NHFGtodP+bjSYEG+GnBEG+EUpAx3Wh/BL2f/sIiSOH9ODB6B847F+apa0OTawmslgGna9/985egGMto9g16EQ4ib1M
-----END PRIVATE KEY-----
''';
  Future<String> performTopUp({required String topUpAmt, required String buyerId}) async {
    final timeInfo = _CryptoUtils.getCurrentTime();
    final data = { "PlatformID": "10000266", "MerchantID": "10000266", "Ccy": "TWD", "TopUpAmt": topUpAmt, "OPSeq": timeInfo['tradeNo'], "StoreId": "982351", "StoreName": "鑫和睦", "PosNo": "01", "OPTime": timeInfo['tradeDate'], "CorpID": "22555003", "PaymentNo": "038", "Remark": "123456", "Itemlist": [{}], "BuyerID": buyerId, };
    return _postRequest(Uri.parse('https://icp-payment-stage.icashpay.com.tw/api/V2/Payment/Pos/SETTopUp'), json.encode(data));
  }
  Future<String> performPayment({required String txAmt, required String buyerId}) async {
    final timeInfo = _CryptoUtils.getCurrentTime();
    final data = { "PlatformID": "10000266", "MerchantID": "10000266", "Ccy":"TWD", "TxAmt": txAmt, "NonRedeemAmt":"", "NonPointAmt":"", "StoreId":"217477", "StoreName": "見晴", "PosNo":"01", "OPSeq": timeInfo['tradeNo'], "OPTime": timeInfo['tradeDate'], "ReceiptNo":"", "ReceiptReriod":"", "TaxID":"", "CorpID":"22555003", "Vehicle":"", "Donate":"", "ItemAmt": txAmt, "UtilityAmt":"", "CommAmt":"", "ExceptAmt1":"", "ExceptAmt2":"", "BonusType":"ByWallet", "BonusCategory":"", "BonusID":"", "PaymentNo": "038", "Remark": "123456", "ReceiptPrint":"N", "Itemlist": [{}], "BuyerID": buyerId };
    return _postRequest(Uri.parse('https://icp-payment-stage.icashpay.com.tw/api/V2/Payment/Pos/SETPay'), json.encode(data));
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

// --- 處理「康是美」相關的服務 (修改此類別) ---
class CosmedApiService {
  // --- 常數 (與 JS 檔案一致，不需變更) ---
  static const String _aesKey = "xtzXnXnjDkhVWXNZlPJ2gMGAElKF28Kw";
  static const String _aesIV = "IeAzH3aBMlD5pvai";
  static const String _encKeyId = "274676";
  static const String _platformId = "10536635";
  static const String _merchantId = "10536635";
  static const String _privateKey = '''
-----BEGIN PRIVATE KEY-----
MIIEogIBAAKCAQEAyScTCR4BQ17b2UP33jhPcdcKQfWyWxk5xoYsxw7+xoWsc6e6KkxqQYY2BMZoMTy/t7Ko8sZnMLDYgaANlEnsDGidy/XoTbXLKNMPXiw9xsCsuQq5DoGlNimu5uvRgTLWsJqb34UBl5lOCHmlvHvdLzw4fO/zlMuSf4pBSFmwVFytJxuNgbXIhZyuVoWiFNR0SIzmouclyHjANaBnRgrXA/KXdvz1CjbCMlZz17L8n6POid9nMvGfUdGfkKxxooYSNyND4lVcb41C9f+l2pXroG9owVwUUgzIa38fmIi3VzxNrJ4vyYlNH5myMU2g7XKgOtWRxauP1jJS6xUEUVDwaQIDAQABAoIBACL6THEVaprQb+JD02Is4IOnJP17P9xfcpB23GpwzRSwQeCKlfCtAP0L3XDPH2cQbTYANyigH2l0FvHTZwkWIZm2x1mkFRUOO5mJue5iOwvIjUBQAQXovVXBwcwdzXxt3q8u81PWyQQXgF4w6QTxdPC1xAzVnMGO9JaA8AEot2SzuYckLjEGXrmUPLZCdJS5wbgwCwJuCxlHjWI0sihRgWs5FbxiHrTTlepSacO0gl4/r2225fbTy4SeSQDf4mKmXX9cEHMSpyCwXKFsQheXYXXvS/514Jomiou2ijTXywibxrv41KfdSK8NYCP85d0hGr0apvoomd7p3+cUuKUrsxECgYEA+t1xFcx79B2s47hcD1cv/AAFt1mjGCqS2AQnDsiCAMEERfx2vudoktUu+7abehWyo0NgkJqmG/xmY2LY/bMGP+OUnUhVDyPBQs4/Q6WIZmrIsIBYOoRzhMIE7VPUwEcD1bMGC0oGrFO3TjNfEd/him9Z+9jK5JFMYXeYj4ZQusMCgYEAzUUifEN0meksTZJo8qK5FPLbCdm7FAMEN/IrKacOO/ZROnFFtxpltezqon5mt2bxIaEbpPSgpNc4bhFpWXX/O/VaW9xVy6YGG5x0YFLaGVpLpvZNdsf0/eIP8X75hDfftKIskhtd9Frjk6zEu+989dipDQ5nRdUfekfNVTYC/WMCgYAOVs358wA6yd9x/L22WsNxYgbxnfwGi5htJH+fBrL3nBDEd1PKQavmiKzw0lU8uzTExDsmyNAp1Vl84M+KYMtAp599Bf9mqCKJ0QQot7N+NyhVfmCMp7l6oyRo9Fu6ydRcSKlVx9ttyjM2ExWiDev0X70C+jdOrUdyYsWjnofKxQKBgE9WMzf4Em8SUk9BEVMGVaalHse14bqgV9cPwGL+8F94mniOIzXb/AfOo/leBXFJVlV7IWYmLpjHnkXccO1kz9tqvxvWE0r8xkuRsuEv5J/76FWFyPbp3eTqpOLgAqx5s/rq23M1JKE3J9KB6iABNjkHHn+vW3cAIoRukAwpLgqlAoGAA3YT/HRvyTF4P+jUBoORsjYbK2/4kJ6Zi5hTRGbkFn9kmRIdJ0sflGrV7y8Av/aE8KBTOqFETvBZQoW47X3BSjDYVqQhvlhtNjEV3cqd7PFLpF8JELh+MRDgvRA+iwozDiG89+lS2cogP8smW6i2VYQsg1fLbQWW5J5lgBHLMq4=
-----END PRIVATE KEY-----''';

  // --- ✨ 此處為主要修改點 ---
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

        // 【修正後的判斷邏輯】
        // 舊邏輯: if (parsedData['PaymentURL'] != null && parsedData['RtnCode'] == 1)
        // 新邏輯: 只要解密後的回應中直接含有 PaymentURL 欄位，就視為成功
        if (parsedData['PaymentURL'] != null && (parsedData['PaymentURL'] as String).isNotEmpty) {
          return parsedData['PaymentURL']; // 成功，回傳 URL
        } else {
          // API 有回傳但內容是錯誤訊息
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

  // --- 現有的「扣款」API (維持不變) ---
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
  // --- UAT 環境參數 ---
  static const String _aesKey = "wetEi4zKeJTDLcXCvqrDduAThvoeUudd";
  static const String _aesIV = "zlHw6q30q2qmWlzD";
  static const String _encKeyId = "117497";
  static const String _privateKey = '''
-----BEGIN PRIVATE KEY-----
MIIEowIBAAKCAQEAyTVkMuX3QXVAlISnNwRgWmVaOEkv/sq0P++q/gAeKBoqMh20jCOO2tmGZ0XsBuvFToA8M1OwcLksGYJUeahd1oh3XerMr87+xS6L6+x3f+q7OJ2q5LGyYXzF06z5ilfnH5oGuwtx5+okU03JkO4pYMXeJC3wHnPD6FwGd4IGdI83qTE8IaE5vBbNshd/I3rLd9ETTNfmpll27gJYKbqDHFgtJoUwqXqo/VcHd2Wsrtma9tHM3Yd+5fl63mccTlN3+OKQnGT2hXtQNa99H9LdiGae+Aq+z/Xsj1VJVbI5P1TTVy6WAyGLQ2X5Kmakv+4LaB4+QDIxjecrCwYDCHlR3QIDAQABAoIBABgJE3rcCz0LyWbkcMgq8uqhfFVIct4ML1uK4QF+GJwgQgWiFEkAT2aXwQ0xplgOTo/J1EcqWmOgzyKN9dLhmLIRs7apn4Fp5/e8j3TjlsPWUb6Z4Qn4Ky+nlMcsPNP4m7Cj+OVboOP8DZJQ8sDoHlPD1z05qpssp4yof5JDm0tNgS/GfOQJFC+bF9xmNtTfqD+T6zeidaARuy/uPhSO2hG+NhNOjxcXwfIXihlGFxRNjTZtHmXDUgR5DXT4oJu0gNiz52QAX0tS4w+S3xsRE+Y7rYVn1oDUSwMSWEycmGfur9Lv6CExrnHB13j26QaZ25MK902tyJlFQYCV8esMO7ECgYEA6kU7Nqryrbld+lgsgg1Ks2nfqpYxnvGL6ITDYThphJdJhPTCITkUFPkVo9KNks3B2K/Hj1fhb7Kr3i80D0pE0Yospj8ZjNt+hieB/mjQ9BmONvdrgxi1fT/4Szwct631X5MJng9Nl23nHGgESV8xzIRs9K/IWUK9P/FArCSDAe0CgYEA298afAyg643Pdpb9qTM9/uJXHNkHHNPU7g+7Z2/mdjC/XZBy03qK7EdfZLZ4r/WXZxxUxwu0C7mAaezPxWZypR4jSSPn2yz0AUMtrVjZnDfZgGbtsynUt9OffgHhRXsRhQ94Lf56W7DteH/TxNwGuOmkgbajC2CcjCMNG4pNUbECgYAhnaWNhqIkA4FUtupMDxQ1AnAxzjN4lzh4OPTAMpQRjpPiHCzvD32uNL/CLihadGPob/C2xOl4Wa8HxsY1m3acirM1d8B20dgp7+lbVDcHj9M0V/R5b0Y7nr5GLW4BfVjEShkLMS71F7QeA176GErRCf+IbODWzhjR4BBjoymZUQKBgQDQ2b+ijaxdk7q5fvs8OXxuHDl7IXvsGhtsdm0g994F7pAYJBmuX/yOK82lMN665aIHQ5YT7D391RrxgwxpCcNkrJf/5adbPfwZJuLAgmFSToq/uQWY5ec1JkOdwdNl2Fzv853Isq0vY4RurZ1OpWGNTAIDZKTDLeYGB1VwD5MaQQKBgBOnuj4zP9rp3G4vqCPWWvk0wV9MYMEXFc96Nm84Tj+YW7x3pxTAXlV1VSeu8jKmdM0HkjQXM1mXfUuJo5WSM1FI1lKAMjLe31fhgxgEA6l4vtikHWXP/4IIyiYBqKyNOnJVxll34qaiYA80SkOEFJxX8QvBgHtWf7x2IKyFthEr
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