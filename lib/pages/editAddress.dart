import 'package:delivery_app/models/address.dart';
import 'package:delivery_app/pages/addNewAddress.dart';

class EditAddressPage extends AddressFormPage {
  EditAddressPage({super.key, required Address address})
      : super(
          uid: address.uid,
          initialAddress: address,
          mode: AddressFormMode.edit,
        );
}
