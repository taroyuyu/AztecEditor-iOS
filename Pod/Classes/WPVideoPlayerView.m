#import "WPVideoPlayerView.h"

@import AVFoundation;

static NSString *playerItemContext = @"ItemStatusContext";


@interface WPVideoPlayerView()

@property (nonatomic, strong) AVPlayer *player;
@property (nonatomic, strong) AVPlayerLayer *playerLayer;
@property (nonatomic, strong) AVPlayerItem *playerItem;
@property (nonatomic, strong) UIToolbar *controlToolbar;
@property (nonatomic, strong) UILabel *videoDurationLabel;
@property (nonatomic, strong) UIBarButtonItem * videoDurationButton;
@property (nonatomic, strong) id timeObserver;

@end

@implementation WPVideoPlayerView

static NSString *tracksKey = @"tracks";

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (!self) {
        return nil;
    }
    [self commonInit];
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    self = [super initWithCoder:coder];
    if (!self) {
        return nil;
    }
    [self commonInit];
    return self;
}

- (void)commonInit {
    self.player = [[AVPlayer alloc] init];
    self.playerLayer = [AVPlayerLayer playerLayerWithPlayer: self.player];
    [self.layer addSublayer: self.playerLayer];
    [self addSubview:self.controlToolbar];

    __weak __typeof__(self) weakSelf = self;
    self.timeObserver = [self.player addPeriodicTimeObserverForInterval:CMTimeMakeWithSeconds(1, NSEC_PER_SEC) queue:nil usingBlock:^(CMTime time) {
        [weakSelf updateVideoDuration];
    }];
}

- (void)dealloc {
    [_playerItem removeObserver:self forKeyPath: @"status"];
    [[NSNotificationCenter defaultCenter] removeObserver: self];
    [_player removeTimeObserver:self.timeObserver];
    [_player pause];
    _asset = nil;
    _player = nil;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    self.playerLayer.frame = self.bounds;
    self.controlToolbar.frame = CGRectMake(0, self.frame.size.height - 44, self.frame.size.width, 44);
}

- (UIToolbar *)controlToolbar {
    if (_controlToolbar) {
        return _controlToolbar;
    }
    _controlToolbar = [[UIToolbar alloc] init];
    [self updateControlToolbar];
    return _controlToolbar;
}

- (UILabel *)videoDurationLabel {
    if (_videoDurationLabel != nil) {
        return _videoDurationLabel;
    }
    _videoDurationLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 100, 44)];
    _videoDurationLabel.backgroundColor = [UIColor redColor];
    _videoDurationLabel.font = [UIFont systemFontOfSize:12];
    _videoDurationLabel.textColor = [UIColor blackColor];
    [_videoDurationLabel sizeToFit];
    return _videoDurationLabel;
}

- (UIBarButtonItem *)videoDurationButton {
    if (_videoDurationButton == nil) {
        _videoDurationButton = [[UIBarButtonItem alloc] initWithTitle:@"" style:UIBarButtonItemStylePlain target:nil action:nil];
    }
    return _videoDurationButton;
}

- (void)setVideoURL:(NSURL *)videoURL {
    _videoURL = videoURL;
    AVURLAsset *asset = [AVURLAsset assetWithURL:videoURL];
    self.asset = asset;
}

- (void)setAsset:(AVAsset *)asset {
    [self.playerItem removeObserver:self forKeyPath: @"status"];
    [[NSNotificationCenter defaultCenter] removeObserver:self];

    _asset = asset;
    self.playerItem = [[AVPlayerItem alloc] initWithAsset: _asset];

    [self.playerItem addObserver:self
                      forKeyPath: @"status"
                         options: NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld
                         context:&playerItemContext];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(playerItemDidReachEnd:)
                                                 name:AVPlayerItemDidPlayToEndTimeNotification
                                               object:self.playerItem];
    [self.player replaceCurrentItemWithPlayerItem: self.playerItem];
    [self play];
}


- (void)playerItemDidReachEnd:(AVPlayerItem *)playerItem {
    if (self.loop) {
        [self.player seekToTime:kCMTimeZero];
        [self.player play];
    }
    if (self.delegate) {
        [self.delegate videoPlayerViewFinish:self];
    }
    [self updateControlToolbar];
}

- (void)play {
    [self.player play];
    [self updateControlToolbar];
    [self updateVideoDuration];
}

- (void)pause {
    [self.player pause];
    [self updateControlToolbar];
}

- (void)togglePlayPause {
    if ([self.player timeControlStatus] == AVPlayerTimeControlStatusPaused) {
        if (CMTimeCompare(self.player.currentItem.currentTime, self.player.currentItem.duration) == 0) {
            [self.player seekToTime:kCMTimeZero];
        }
        [self play];
    } else {
        [self pause];
    }
}

- (void)setControlToolbarHidden:(BOOL)hidden animated:(BOOL)animated {
    CGFloat animationDuration = animated ? UINavigationControllerHideShowBarDuration : 0;
    if (!hidden) {
        self.controlToolbar.hidden = hidden;
    }
    [UIView animateWithDuration:animationDuration animations:^{
        CGFloat position = self.controlToolbar.frame.size.height;
        if (hidden) {
            position = 0;
        }
        self.controlToolbar.frame = CGRectMake(0, self.frame.size.height - position, self.frame.size.width, 44);
    } completion:^(BOOL finished) {
        self.controlToolbar.hidden = hidden;
    }];
}

- (void)setControlToolbarHidden:(BOOL)hidden {
    [self setControlToolbarHidden:hidden animated:NO];
}

- (BOOL)controlToolbarHidden {
    return self.controlToolbar.hidden;
}

- (void)updateControlToolbar {
    UIBarButtonSystemItem playPauseButton = [self.player timeControlStatus] == AVPlayerTimeControlStatusPaused ? UIBarButtonSystemItemPlay : UIBarButtonSystemItemPause;

    self.controlToolbar.items = @[
                                  [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil],
                                  [[UIBarButtonItem alloc] initWithBarButtonSystemItem:playPauseButton target:self action:@selector(togglePlayPause)],
                                  [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil],
                                  self.videoDurationButton,
                                  ];
}

- (void)updateVideoDuration {
    AVPlayerItem *playerItem = self.player.currentItem;
    if (!playerItem || playerItem.status != AVPlayerItemStatusReadyToPlay) {
        return;
    }
    double totalSeconds = CMTimeGetSeconds(playerItem.duration);
    double currentSeconds = CMTimeGetSeconds(playerItem.currentTime);
    NSString *totalDuration = [self stringFromTimeInterval:totalSeconds];
    NSString *currentDuration = [self stringFromTimeInterval:currentSeconds];
    self.videoDurationButton.title = [NSString stringWithFormat:@"%@/%@", currentDuration, totalDuration];
}

- (NSString *)stringFromTimeInterval:(NSTimeInterval)timeInterval
{
    NSInteger roundedHours = floor(timeInterval / 3600);
    NSInteger roundedMinutes = floor((timeInterval - (3600 * roundedHours)) / 60);
    NSInteger roundedSeconds = round(timeInterval - (roundedHours * 60 * 60) - (roundedMinutes * 60));

    if (roundedHours > 0)
        return [NSString stringWithFormat:@"%ld:%02ld:%02ld", (long)roundedHours, (long)roundedMinutes, (long)roundedSeconds];

    else
        return [NSString stringWithFormat:@"%ld:%02ld", (long)roundedMinutes, (long)roundedSeconds];
}

- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary<NSKeyValueChangeKey,id> *)change
                       context:(void *)context
{
    // Only handle observations for the playerItemContext
    if (context != &playerItemContext) {
        [super observeValueForKeyPath: keyPath
                             ofObject: object
                               change: change
                              context: context];
        return;
    }

    if ( [keyPath isEqualToString:@"status"]) {
        AVPlayerItemStatus status;
        NSNumber *statusNumber = change[NSKeyValueChangeNewKey];
        // Get the status change from the change dictionary
        if (statusNumber) {
            status = (AVPlayerItemStatus)[statusNumber intValue];
        } else {
            status = AVPlayerItemStatusUnknown;
        }

        // Switch over the status
        switch (status) {
            case AVPlayerItemStatusReadyToPlay:{
                // Player item is ready to play.
                if (self.delegate) {
                    [self.delegate videoPlayerViewStarted:self];
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [self updateVideoDuration];
                    });
                }
            }
                break;
            case AVPlayerItemStatusFailed: {
                // Player item failed. See error.
                NSError *error = [self.playerItem error];
                if (self.delegate) {
                    [self.delegate videoPlayerView:self didFailWithError: error];
                }
            }
                break;
            case AVPlayerItemStatusUnknown:
                // Player item is not yet ready.
                return;
                break;
        }
    }
}

@end

