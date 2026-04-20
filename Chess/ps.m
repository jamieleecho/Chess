//
//  ps.c
//  Chess
//
//  Created by Jamie Cho on 3/15/26.
//

#include <Cocoa/Cocoa.h>


void PSWait(void) {
}


void PSclip(void) {
}


void PSclippath(void) {
}


void PSclosepath(void) {
}


void PScomposite(float x, float y, float w, float h, int gstateNum, float dx, float dy, int op) {
}


void PScompositerect(float x, float y, float w, float h, int op) {
    NSRectFillUsingOperation(NSMakeRect(x, y, w, h), (NSCompositingOperation)op);
}


void PSgrestore(void) {
}


void PSgsave(void) {
}


void PSnewpath(void) {
}


void PSrectfill(float x, float y, float w, float h) {
    NSRectFill(NSMakeRect(x, y, w, h));
}


void PSrectstroke(float x, float y, float w, float h) {
}


void PSlineto(float x, float y) {
}


void PSrlineto(float x, float y) {
}


void PSrotate(float angle) {
}


void PSmoveto(float x, float y) {
}


void PSsetlinewidth(float width) {
}


void PSsetgray(float gray) {
    [[NSColor colorWithWhite:gray alpha:1] set];
}


void PSstroke(void) {
}


void PStranslate(float x, float y) {
}


