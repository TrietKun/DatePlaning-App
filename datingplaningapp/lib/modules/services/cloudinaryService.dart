import 'dart:io';
import 'package:cloudinary_public/cloudinary_public.dart';

class CloudinaryService {
  static final CloudinaryPublic cloudinary = CloudinaryPublic(
    'dkwb3ddwa', // replace with your Cloudinary cloud name
    'dateplanning_app_uploads', // replace with your upload preset
    cache: false,
  );

  static Future<String> uploadImage(File imageFile, String folder) async {
    try {
      CloudinaryResponse response = await cloudinary.uploadFile(
        CloudinaryFile.fromFile(
          imageFile.path,
          folder: folder,
          resourceType: CloudinaryResourceType.Image,
        ),
      );
      return response.secureUrl;
    } catch (e) {
      throw Exception('Failed to upload image: $e');
    }
  }

  // static Future<void> deleteImage(String publicId) async {
  //   try {
  //     await cloudinary.deleteFile(
  //       publicId: publicId,
  //       resourceType: CloudinaryResourceType.Image,
  //       invalidate: true,
  //     );
  //   } catch (e) {
  //     throw Exception('Failed to delete image: $e');
  //   }
  // }

  // Extract public_id from Cloudinary URL
  static String? getPublicIdFromUrl(String url) {
    try {
      final uri = Uri.parse(url);
      final pathSegments = uri.pathSegments;
      final indexOfUpload = pathSegments.indexOf('upload');
      if (indexOfUpload != -1 && pathSegments.length > indexOfUpload + 2) {
        final publicIdWithExtension =
            pathSegments.sublist(indexOfUpload + 2).join('/');
        return publicIdWithExtension.split('.').first;
      }
      return null;
    } catch (e) {
      return null;
    }
  }
}
