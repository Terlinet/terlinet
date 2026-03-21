import 'package:flutter_web3/flutter_web3.dart';
import 'package:url_launcher/url_launcher.dart';

Future<String?> connectMetamaskLogic() async {
  if (ethereum == null) {
    final Uri url = Uri.parse('https://chromewebstore.google.com/detail/nkbihfbeogaeaoehlefnkodbefgpgknn');
    await launchUrl(url, mode: LaunchMode.externalApplication);
    return null;
  }

  try {
    final accs = await ethereum!.getAccounts();
    if (accs.isNotEmpty) {
      return accs.first;
    }
  } catch (e) {
    print('Erro Metamask: $e');
  }
  return null;
}
