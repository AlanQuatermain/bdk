#import "AQOptionsManager.h"
#import "AQHarnessController.h"
#import "AQAppManager.h"
#import "AQNSWindowRenderer.h"

#import <BackRow/BackRow.h>
#import <unistd.h>

@implementation AQOptionsManager

+ (void) initialize
{
    NSMutableDictionary * initPrefs = [NSMutableDictionary dictionary];
    [initPrefs setObject: [NSNumber numberWithInt: 0] forKey: @"RunMode"];
    [initPrefs setObject: [NSArray array] forKey: @"PluginHistory"];
    [initPrefs setObject: @"" forKey: @"CurrentPlugin"];
    [initPrefs setObject: [NSNumber numberWithInt: NSOffState] forKey: @"ShowFPS"];
    [initPrefs setObject: [NSNumber numberWithInt: NSOffState] forKey: @"PrintRenderTree"];
    [initPrefs setObject: [NSNumber numberWithInt: NSOffState] forKey: @"ShowSafeAreas"];
    [initPrefs setObject: [NSNumber numberWithInt: NSOffState] forKey: @"FixMainMenu"];
    [[NSUserDefaults standardUserDefaults] registerDefaults: initPrefs];
}

- (void) awakeFromNib
{
    NSUserDefaults * defaults = [NSUserDefaults standardUserDefaults];
    [pluginPathField addItemsWithObjectValues: [defaults objectForKey: @"PluginHistory"]];
    [pluginPathField setStringValue: [defaults objectForKey: @"CurrentPlugin"]];
    [modeMatrix selectCellAtRow: [defaults integerForKey: @"RunMode"] column: 0];
    [showFPSButton setState: [defaults integerForKey: @"ShowFPS"]];
    [printRenderTreeButton setState: [defaults integerForKey: @"PrintRenderTree"]];
    [showSafeAreasButton setState: [defaults integerForKey: @"ShowSafeAreas"]];
    [applyMainMenuFixButton setState: [defaults integerForKey: @"FixMainMenu"]];

    if ( [defaults integerForKey: @"RunMode"] == 1 )
        [pluginPathField setEnabled: YES];

    char * env = getenv( "BDKStartupWithRootItem" );

    if ( (env != NULL) && (env[0] != '\0') )
    {
        NSLog( @"Got BDKStartupWithRootItem '%s'", env );
        NSString * path = [NSString stringWithUTF8String: env];
        if ( [[NSFileManager defaultManager] fileExistsAtPath: path] )
        {
            // convert it to an absolute path
            if ( [path isAbsolutePath] == NO )
                path = [[[NSFileManager defaultManager] currentDirectoryPath]
                        stringByAppendingPathComponent: path];

            [pluginPathField setStringValue: path];
            [modeMatrix selectCellAtRow: 1 column: 0];
            [[NSUserDefaults standardUserDefaults] setInteger: 1 forKey: @"RunMode"];

            [self startInterface: startButton];
        }
    }
}

- (IBAction) startInterface: (id) sender
{
    AQHarnessController * controller = [AQHarnessController sharedController];
    if ( ([[NSUserDefaults standardUserDefaults] integerForKey: @"RunMode"] == 1) &&
         ([[NSFileManager defaultManager] fileExistsAtPath: [pluginPathField stringValue]]) )
    {
        if ( [controller setRootItemByPath: [pluginPathField stringValue]] )
        {
            // if that was a valid plugin, we'll include it in the list
            NSMutableSet * set = [NSMutableSet setWithArray: [pluginPathField objectValues]];
            [set addObject: [pluginPathField stringValue]];
            [pluginPathField removeAllItems];
            [pluginPathField addItemsWithObjectValues: [set allObjects]];
        }
    }
    else
    {
        (void) [controller setRootItemByPath: nil];
    }

    if ( [applyMainMenuFixButton state] == NSOnState )
        [controller setMainMenuFixEnabled: YES];
    else
        [controller setMainMenuFixEnabled: NO];
    
    [controller setupRemoteHID];
    [controller setSceneShowsFPS: ([showFPSButton state] == NSOffState ? NO : YES)];
    [controller setScenePrintsRenderTree: ([printRenderTreeButton state] == NSOffState ? NO : YES)];
    [controller setSceneShowsSafeAreas: ([showSafeAreasButton state] == NSOffState ? NO : YES)];

    [[BREventManager sharedManager] setFirstResponder: controller];

    [[NSNotificationCenter defaultCenter] addObserver: self
                                             selector: @selector(_handleBackRowTermination:)
                                                 name: AQNSWindowRendererGoingAway
                                               object: nil];

    // run the BackRow application
    [[AQAppManager sharedApplication] run];

    [stopButton setEnabled: YES];
    [sender setEnabled: NO];
    [applyMainMenuFixButton setEnabled: NO];
}

- (IBAction) stopInterface: (id) sender
{
    [[AQAppManager sharedApplication] terminate];
    /*[[AQHarnessController sharedController] tearDownRemoteHID];

    [startButton setEnabled: YES];
    [sender setEnabled: NO];*/
}

- (IBAction) modeSelectionChanged: (id) sender
{
    int row = [sender selectedRow];
    if ( row == 1 )
        [pluginPathField setEnabled: YES];
    else
        [pluginPathField setEnabled: NO];

    [[NSUserDefaults standardUserDefaults] setInteger: row forKey: @"RunMode"];
}

- (IBAction) checkboxHit: (id) sender
{
    int state = [sender state];
    BOOL setNow = ([startButton isEnabled] == NO);
    BOOL toggle = (state == NSOffState ? NO : YES);

    if ( sender == showFPSButton )
    {
        [[NSUserDefaults standardUserDefaults] setInteger: state forKey: @"ShowFPS"];
        if ( setNow )
            [[AQHarnessController sharedController] setSceneShowsFPS: toggle];
    }
    else if ( sender == printRenderTreeButton )
    {
        [[NSUserDefaults standardUserDefaults] setInteger: state forKey: @"PrintRenderTree"];
        if ( setNow )
            [[AQHarnessController sharedController] setScenePrintsRenderTree: toggle];
    }
    else if ( sender == showSafeAreasButton )
    {
        [[NSUserDefaults standardUserDefaults] setInteger: state forKey: @"ShowSafeAreas"];
        if ( setNow )
            [[AQHarnessController sharedController] setSceneShowsSafeAreas: toggle];
    }
    else if ( sender == applyMainMenuFixButton )
    {
        [[NSUserDefaults standardUserDefaults] setInteger: state forKey: @"FixMainMenu"];

        // this one is set only upon clicking 'start', to ensure it
        // overrides any tweaks made by plugins
    }
}

- (void) applicationWillTerminate: (NSApplication *) application
{
    NSUserDefaults * defaults = [NSUserDefaults standardUserDefaults];
    [defaults setObject: [pluginPathField stringValue] forKey: @"CurrentPlugin"];
    [defaults setObject: [pluginPathField objectValues] forKey: @"PluginHistory"];
    [defaults synchronize];
}

- (void) _handleBackRowTermination: (NSNotification *) note
{
    [[AQHarnessController sharedController] tearDownRemoteHID];

    [startButton setEnabled: YES];
    [stopButton setEnabled: NO];
    [applyMainMenuFixButton setEnabled: YES];

    [optionsWindow makeKeyAndOrderFront: self];
}

@end
