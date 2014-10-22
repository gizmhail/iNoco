//
//  commonSettings.h
//  iNoco
//
//  Created by Sébastien POIVRE on 08/10/2014.
//  Copyright (c) 2014 Sébastien Poivre. All rights reserved.
//

#ifndef iNoco_commonSettings_h
#define iNoco_commonSettings_h


#define HACK_AUTH_WEBPAGE_REMOVE_ACCOUNT_CREATION 1

//#define TRUST_BACKEND_QUALITY_ADAPTATION false

#define ALWAYS_DISPLAY_READFILTER_IN_RECENT_SHOWS false

#define ALL_SUBSCRIPTED_CATALOG @"ALLSUBSCRIPTED_CATALOG"
#define ALL_NOCO_CATALOG @"ALL_NOCO_CATALOG"
#define DEFAULT_CATALOG ALL_NOCO_CATALOG

#define DEFAULT_LANGUAGE @"V.O."
#define DEFAULT_SUBTITLE_LANGUAGE @"fr"
#define DEFAULT_QUALITY @"LQ"

#define PROGRESS_UPDATE_UPLOAD_STEP_TIME 60*2

//#define THEME_COLOR [UIColor colorWithRed:0.275126 green:0.604248 blue:0.91546 alpha:1]
#define THEME_COLOR [UIColor colorWithRed:0x0/255.0 green:0x88/255.0 blue:0xCC/255.0f alpha:1]
#define SELECTED_VALID_COLOR [UIColor colorWithRed:0x9E/255.0 green:0xC7/255.0 blue:0x0F/255.0f alpha:1]

#define ALLOW_DOWNLOADS 1


#pragma mark -
#pragma mark Extensions

#define INOCO_GROUPNAME @"group.name.poivre.iNoco"

//Debugging group logs
#ifdef DEBUG
#define NLT_RECORD_LOGS 1
#endif

#endif
