/* AQOptionsManager */

#import <Cocoa/Cocoa.h>

@interface AQOptionsManager : NSObject
{
    IBOutlet NSMatrix *modeMatrix;
    IBOutlet NSWindow *optionsWindow;
    IBOutlet NSComboBox *pluginPathField;
    IBOutlet NSButton *startButton;
    IBOutlet NSButton *stopButton;
    IBOutlet NSButton *showFPSButton;
    IBOutlet NSButton *printRenderTreeButton;
    IBOutlet NSButton *showSafeAreasButton;
    IBOutlet NSButton *applyMainMenuFixButton;
}

- (IBAction) startInterface: (id) sender;
- (IBAction) stopInterface: (id) sender;
- (IBAction) modeSelectionChanged: (id) sender;
- (IBAction) checkboxHit: (id) sender;

@end
