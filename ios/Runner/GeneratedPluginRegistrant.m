//
//  Generated file. Do not edit.
//

// clang-format off

#import "GeneratedPluginRegistrant.h"

#if __has_include(<audiotags/AudiotagsPlugin.h>)
#import <audiotags/AudiotagsPlugin.h>
#else
@import audiotags;
#endif

#if __has_include(<ffmpeg_kit_flutter_audio/FFmpegKitFlutterPlugin.h>)
#import <ffmpeg_kit_flutter_audio/FFmpegKitFlutterPlugin.h>
#else
@import ffmpeg_kit_flutter_audio;
#endif

#if __has_include(<path_provider_foundation/PathProviderPlugin.h>)
#import <path_provider_foundation/PathProviderPlugin.h>
#else
@import path_provider_foundation;
#endif

#if __has_include(<permission_handler_apple/PermissionHandlerPlugin.h>)
#import <permission_handler_apple/PermissionHandlerPlugin.h>
#else
@import permission_handler_apple;
#endif

@implementation GeneratedPluginRegistrant

+ (void)registerWithRegistry:(NSObject<FlutterPluginRegistry>*)registry {
  [AudiotagsPlugin registerWithRegistrar:[registry registrarForPlugin:@"AudiotagsPlugin"]];
  [FFmpegKitFlutterPlugin registerWithRegistrar:[registry registrarForPlugin:@"FFmpegKitFlutterPlugin"]];
  [PathProviderPlugin registerWithRegistrar:[registry registrarForPlugin:@"PathProviderPlugin"]];
  [PermissionHandlerPlugin registerWithRegistrar:[registry registrarForPlugin:@"PermissionHandlerPlugin"]];
}

@end
