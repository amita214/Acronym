//
//  ViewController.m
//  Acronyms
//
//  Created by Amita Pai on 2/19/16.
//  Copyright © 2016 Amita Pai. All rights reserved.
//

#import "ViewController.h"
#import "AFNetworking.h"
#import "MBProgressHUD.h"

@interface ViewController () <UITableViewDataSource, UITableViewDelegate, UITextFieldDelegate> {
    NSString *_abbreviation;
    
    BOOL _networkNotReachable;
}

@property (nonatomic, strong) NSMutableArray *acronymList;

@property (weak, nonatomic) IBOutlet UITextField *searchTextField;
@property (weak, nonatomic) IBOutlet UITableView *tableView;
@property (weak, nonatomic) IBOutlet UILabel *nothingFoundLabel;
@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.acronymList = [NSMutableArray array];
    
    [[AFNetworkReachabilityManager sharedManager] setReachabilityStatusChangeBlock:^(AFNetworkReachabilityStatus status) {
        if (status <= 0) {
            UIAlertAction *action = [UIAlertAction actionWithTitle:@"Open"
                                                             style:UIAlertActionStyleDefault
                                                           handler:^(UIAlertAction * _Nonnull action) {
                                                               [[UIApplication sharedApplication] openURL:[NSURL URLWithString:UIApplicationOpenSettingsURLString]];
                                                           }];
            [self showAlertWithMessage:[NSString stringWithFormat:@"Check network setting. %@", AFStringFromNetworkReachabilityStatus(status)] okAction:action];
            _networkNotReachable = YES;
        } else {
            _networkNotReachable = NO;
        }
    }];
    
    [[AFNetworkReachabilityManager sharedManager] startMonitoring];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - IB Outlets
- (IBAction)searchAction:(UIButton *)sender {
    [self retrieveDefinition];
}

- (void)showAlertWithMessage:(NSString *)message okAction:(UIAlertAction *)action {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:[[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleName"]
                                                                   message:message
                                                            preferredStyle:UIAlertControllerStyleAlert];
    
    if (action) {
        [alert addAction:action];
    }
    
    [alert addAction:[UIAlertAction actionWithTitle:@"Cancel"
                                              style:UIAlertActionStyleDefault
                                            handler:^(UIAlertAction *action) {
                                                
                                            }]];
    
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)retrieveDefinition {
    _abbreviation = [self.searchTextField.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    
    [self.acronymList removeAllObjects];
    if (_networkNotReachable) {
        return;
    }
    
    MBProgressHUD *hud = [MBProgressHUD showHUDAddedTo:self.view animated:YES];
    hud.mode = MBProgressHUDModeAnnularDeterminate;
    hud.labelText = @"Loading...";
    dispatch_async(dispatch_get_global_queue( DISPATCH_QUEUE_PRIORITY_LOW, 0), ^{
        // Format URL
        NSString *string = [NSString stringWithFormat:@"http://www.nactem.ac.uk/software/acromine/dictionary.py?sf=%@", _abbreviation];
        NSURL *url = [NSURL URLWithString:string];
        NSURLRequest *request = [NSURLRequest requestWithURL:url];
        
        // Get data task and resume it
        NSURLSessionConfiguration *configuration = [NSURLSessionConfiguration defaultSessionConfiguration];
        AFURLSessionManager *manager = [[AFURLSessionManager alloc] initWithSessionConfiguration:configuration];
        manager.responseSerializer = [AFHTTPResponseSerializer serializer];
        NSURLSessionDataTask *dataTask = [manager dataTaskWithRequest:request completionHandler:^(NSURLResponse *response, id responseObject, NSError *error) {
            if (error) {
                [self errorWhileRetrieving:error];
            } else {
                NSArray *responseArray = [NSJSONSerialization JSONObjectWithData:responseObject options:NSJSONReadingMutableContainers error:&error];
                if (error) {
                    [self errorWhileRetrieving:error];
                } else {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        if (responseArray.count > 0) {
                            [self.acronymList addObjectsFromArray: responseArray[0][@"lfs"]];
                            
                            self.tableView.hidden = NO;
                            [self.tableView reloadData];
                        } else {
                            self.nothingFoundLabel.hidden = NO;
                        }
                    });
                    
                }
                
                dispatch_async(dispatch_get_main_queue(), ^{
                    [hud hide:YES];
                });
            }
        }];
        [dataTask resume];
    });
    [self.searchTextField resignFirstResponder];
}

- (void)errorWhileRetrieving:(NSError *)error {
    NSLog(@"Error: %@", error);
    dispatch_async(dispatch_get_main_queue(), ^{
        [[MBProgressHUD HUDForView:self.view] hide:YES];
    });
}

#pragma mark - Text Field Delegate
- (void)textFieldDidBeginEditing:(UITextField *)textField {
    self.tableView.hidden = YES;
    self.nothingFoundLabel.hidden = YES;
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    [self retrieveDefinition];
    return YES;
}

#pragma mark - Table View Data Source
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.acronymList.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"acronymCell" forIndexPath:indexPath];
    
    NSDictionary *data = self.acronymList[indexPath.row];
    cell.textLabel.text = [_abbreviation uppercaseString];
    cell.detailTextLabel.text = [data[@"lf"] capitalizedString];
    return cell;
}

@end
