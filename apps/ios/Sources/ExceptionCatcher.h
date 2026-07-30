#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// AVFAudio는 상태가 어긋나면 오류가 아니라 NSException을 던지고, Swift는 그것을
/// 잡을 수 없어 앱이 통째로 죽는다. 이 심(shim) 하나가 그 사이에 선다.
@interface ExceptionCatcher : NSObject
/// tryBlock이 NSException 없이 끝나면 YES. 던지면 잡아서 NO.
+ (BOOL)catchException:(void (NS_NOESCAPE ^)(void))tryBlock;
@end

NS_ASSUME_NONNULL_END
