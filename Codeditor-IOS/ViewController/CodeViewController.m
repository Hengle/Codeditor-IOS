//
//  CodeViewController.m
//  Codeditor-IOS
//
//  Created by GuessEver on 16/8/19.
//  Copyright © 2016年 QKTeam. All rights reserved.
//

#import "CodeViewController.h"
#import "TimeModel.h"

@implementation CodeViewController

NSString* getSuffix(NSString* filename) {
    NSRegularExpression* regex = [NSRegularExpression regularExpressionWithPattern:@"\\.((?!\\.).)*?$" options:0 error:nil];
    __block NSString* suffix = @"";
    [regex enumerateMatchesInString:filename options:0 range:NSMakeRange(0, filename.length) usingBlock:^(NSTextCheckingResult * _Nullable result, NSMatchingFlags flags, BOOL * _Nonnull stop) {
        suffix = [filename substringWithRange:NSMakeRange(result.range.location + 1, result.range.length - 1)];
        *stop = YES;
    }];
    return suffix;
}

- (instancetype)initWithCodeData:(FileModel*)code {
    if(self = [super init]) {
        self.code = code;
        self.deleted = NO;
        
        self.navigationItem.rightBarButtonItems = @[
                                                    [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemTrash target:self action:@selector(deleteCodeConfirm:)],
                                                    [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemReply target:self action:@selector(copyCode)]
                                                    ];
        self.navigationItem.titleView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 150, 44)];
        self.filenameInput = [[UITextField alloc] init];
        [self.filenameInput setAutocorrectionType:UITextAutocorrectionTypeNo];
        [self.filenameInput setAutocapitalizationType:UITextAutocapitalizationTypeNone];
        [self.filenameInput setTextAlignment:NSTextAlignmentCenter];
        [self.navigationItem.titleView addSubview:self.filenameInput];
        [self.filenameInput mas_makeConstraints:^(MASConstraintMaker *make) {
            make.top.equalTo(self.navigationItem.titleView.mas_top);
            make.left.equalTo(self.navigationItem.titleView.mas_left);
            make.width.equalTo(self.navigationItem.titleView.mas_width);
            make.height.equalTo(self.navigationItem.titleView.mas_height);
        }];
        [self.filenameInput setText:self.code.filename];
        [self.filenameInput setDelegate:self];
        
        CodeEditorLanguageType languageType = [CodeEditorLanguage getLanguageByFileSuffixName:getSuffix(self.code.filename)];
        self.codeView = [[CodeEditorView alloc] initWithLanguage:languageType];
        [self.view addSubview:self.codeView];
        [self.codeView mas_makeConstraints:^(MASConstraintMaker *make) {
            make.top.equalTo(self.view.mas_top);
            make.right.equalTo(self.view.mas_right);
            make.bottom.equalTo(self.view.mas_bottom);
            make.left.equalTo(self.view.mas_left);
        }];
        [self.codeView loadText:self.code.content];
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardShowOrHide:) name:UIKeyboardDidShowNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardShowOrHide:) name:UIKeyboardDidHideNotification object:nil];
    }
    return self;
}
- (instancetype)init {
    if(self = [self initWithCodeData:[[FileModel alloc] initWithFilename:@"noname" content:@""]]) {
        [self renewFilename];
        [self.code saveFile];
    }
    return self;
}

- (void)keyboardShowOrHide:(NSNotification*)notification {
    CGRect keyboardFrame = [[notification.userInfo objectForKey:UIKeyboardFrameEndUserInfoKey] CGRectValue];
    [self.codeView mas_updateConstraints:^(MASConstraintMaker *make) {
        make.bottom.equalTo(self.view.mas_bottom).offset(keyboardFrame.origin.y - self.view.frame.size.height);
    }];
    [self.codeView setNeedsUpdateConstraints];
}

- (void)viewWillDisappear:(BOOL)animated {
    if(!self.deleted) {
        [self.code renewContent:self.codeView.text];
        [self.code saveFile];
    }
}

- (void)renewFilename {
    while(![self.code renewFilename:self.filenameInput.text]) {
        NSString* suffix = getSuffix(self.filenameInput.text);
        if(![suffix isEqualToString:@""]) {
            suffix = [@"." stringByAppendingString:suffix];
        }
        __block NSString* prefix = [self.filenameInput.text substringWithRange:NSMakeRange(0, self.filenameInput.text.length - suffix.length)];
        NSRegularExpression* regex = [NSRegularExpression regularExpressionWithPattern:@"\\(([0-9]+)\\)$" options:0 error:nil];
        __block BOOL hasNumberSuffix = NO;
        [regex enumerateMatchesInString:prefix options:0 range:NSMakeRange(0, prefix.length) usingBlock:^(NSTextCheckingResult * _Nullable result, NSMatchingFlags flags, BOOL * _Nonnull stop) {
            hasNumberSuffix = YES;
            NSRange numberRange = [result rangeAtIndex:1];
            NSInteger number = [[prefix substringWithRange:numberRange] integerValue];
            NSString* nextNumberString = [NSString stringWithFormat:@"%ld", (long)number + 1];
            prefix = [prefix stringByReplacingCharactersInRange:numberRange withString:nextNumberString];
        }];
        if(!hasNumberSuffix) {
            prefix = [prefix stringByAppendingString:@" (1)"];
        }
        [self.filenameInput setText:[prefix stringByAppendingString:suffix]];
    }
}
- (void)renewCode {
    [self.code renewContent:self.codeView.text];
    [self.code saveFile];
    CodeEditorLanguageType languageType = [CodeEditorLanguage getLanguageByFileSuffixName:getSuffix(self.code.filename)];
    [self.codeView setLanguageType:languageType];
}
- (void)copyCode {
    [self renewCode];
    [self renewFilename];
    [self renewCode];
}
- (void)deleteCodeConfirm:(UIBarButtonItem*)sender {
    UIAlertController* alertController = [[UIAlertController alloc] init];
    UIAlertAction* confirmAction = [UIAlertAction actionWithTitle:@"Delete" style:UIAlertActionStyleDestructive handler:^(UIAlertAction * _Nonnull action) {
        [self deleteCode];
    }];
    [alertController addAction:confirmAction];
    UIPopoverPresentationController* popoverController = alertController.popoverPresentationController;
    if(popoverController) {
        [popoverController setBarButtonItem:sender];
    }
    [self presentViewController:alertController animated:YES completion:nil];
}
- (void)deleteCode {
    [self.code deleteFile];
    self.deleted = YES;
    [self.navigationController popViewControllerAnimated:YES];
}

#pragma mark UITextFieldDelegate
- (void)textFieldDidBeginEditing:(UITextField *)textField {
    [textField selectAll:textField];
}
- (void)textFieldDidEndEditing:(UITextField *)textField {
    [self.code deleteFile];
    [self renewFilename];
    [self renewCode];
    
}

@end
