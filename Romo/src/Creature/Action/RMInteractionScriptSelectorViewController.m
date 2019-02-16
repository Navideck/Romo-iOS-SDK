//
//  RMInteractionScriptSelectorViewController.m
//  Romo
//
//  Created on 10/15/13.
//  Copyright (c) 2013 Romotive. All rights reserved.
//

#import "RMInteractionScriptSelectorViewController.h"
#import <Romo/UIApplication+Environment.h>

@interface RMInteractionScriptSelectorViewController () <UITableViewDelegate, UITableViewDataSource>

@property (nonatomic, copy) RMInteractionScriptSelectorViewControllerCompletion completion;
@property (nonatomic, strong) NSArray *scriptNames;

@property (nonatomic, strong) UITableView *tableView;

@end

@implementation RMInteractionScriptSelectorViewController

- (instancetype)initWithCompletion:(RMInteractionScriptSelectorViewControllerCompletion)completion
{
    self = [super init];
    if (self) {
        _completion = completion;
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.tableView = [[UITableView alloc] initWithFrame:self.view.bounds];
    self.tableView.tableHeaderView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 320, 50)];
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    [self.view addSubview:self.tableView];
    
    UIButton *cancelButton = [UIButton buttonWithType:UIButtonTypeRoundedRect];
    cancelButton.frame = CGRectMake(5, 5, 80, 40);
    [cancelButton setTitle:NSLocalizedString(@"Cancel", @"Cancel") forState:UIControlStateNormal];
    [cancelButton addTarget:self action:@selector(handleCancel:) forControlEvents:UIControlEventTouchUpInside];
    
    [self.tableView.tableHeaderView addSubview:cancelButton];
    
    NSString *server = [UIApplication environmentVariableWithKey:@"INTERACTION_SCRIPT_SERVER"];
    
    // Fetch scripts
    NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL URLWithString:[NSString stringWithFormat:@"http://%@/scripts", server]]];

    if (@available(iOS 8.0, *)) {
        NSURLSession *session = [[NSURLSession alloc]init];
        [session dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
            if (((NSHTTPURLResponse *)response).statusCode != 200 || error) {
                NSLog(@"Error fetching data: %@, %@", response, error);

                UIAlertController* alert = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"Server Down?", @"Server Down?")
                                                                               message:NSLocalizedString(@"You probably need to either configure the env variable to point to your machine, or start the node server. For more details see: RMInteractionScriptSelectorViewController.h",@"You probably need to either configure the env variable to point to your machine, or start the node server. For more details see: RMInteractionScriptSelectorViewController.h")
                                                                        preferredStyle:UIAlertControllerStyleAlert];

                UIAlertAction* defaultAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"Dismiss",@"Dismiss") style:UIAlertActionStyleDefault
                                                                      handler:^(UIAlertAction * action) {}];

                [alert addAction:defaultAction];
                [self presentViewController:alert animated:YES completion:nil];
            } else {
                self.scriptNames = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
                [self.tableView reloadData];
            }
        }];
    } else {
        // Fallback on earlier versions
        [NSURLConnection sendAsynchronousRequest:request queue:[NSOperationQueue mainQueue] completionHandler:^(NSURLResponse *response, NSData *data, NSError *connectionError) {
            if (((NSHTTPURLResponse *)response).statusCode != 200 || connectionError) {
                NSLog(@"Error fetching data: %@, %@", response, connectionError);

                [[[UIAlertView alloc] initWithTitle:@"Server Down?"
                                            message:@"You probably need to either configure the env variable to point to your machine, or start the node server. For more details see: RMInteractionScriptSelectorViewController.h"
                                           delegate:nil
                                  cancelButtonTitle:@"Dismiss"
                                  otherButtonTitles:nil] show];
            } else {
                self.scriptNames = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
                [self.tableView reloadData];
            }
        }];
    }
}

#pragma mark - UI events

- (void)handleCancel:(id)sender
{
    self.completion(NO, nil);
}

#pragma mark - UITableViewDelegate / UITableViewDataSource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return self.scriptNames.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"script-cell"];
    
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"script-cell"];
    }
    
    cell.textLabel.text = self.scriptNames[indexPath.row];
    
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    NSString *scriptName = self.scriptNames[indexPath.row];
    NSString *server = [UIApplication environmentVariableWithKey:@"INTERACTION_SCRIPT_SERVER"];
    
    NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL URLWithString:[NSString stringWithFormat:@"http://%@/scripts/%@", server, scriptName]]];
    [NSURLConnection sendAsynchronousRequest:request queue:[NSOperationQueue mainQueue] completionHandler:^(NSURLResponse *response, NSData *data, NSError *connectionError) {
        if (((NSHTTPURLResponse *)response).statusCode != 200 || connectionError) {
            NSLog(@"Error fetching data: %@, %@", response, connectionError);
        } else {
            NSDictionary *script = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
            self.completion(YES, script);
        }
    }];
}

@end
