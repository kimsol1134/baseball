#import "ExceptionCatcher.h"

@implementation ExceptionCatcher
+ (BOOL)catchException:(void (NS_NOESCAPE ^)(void))tryBlock {
    @try {
        tryBlock();
        return YES;
    } @catch (NSException *exception) {
        // 소리는 게임의 전제 조건이 아니다. 삼키고, 호출부가 엔진을 재시작하게 둔다.
        return NO;
    }
}
@end
