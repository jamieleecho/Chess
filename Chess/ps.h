//
//  ps.h
//  Chess
//
//  Created by Jamie Cho on 3/15/26.
//

#ifndef ps_h
#define ps_h

#import <AppKit/NSGraphics.h>


void PSgsave(void);
void PSgrestore(void);
void PSWait(void);

void PScountframebuffers(int *count);
void PSmoveto(float x, float y);
void PSrmoveto(float x, float y);
void PSarc(float x, float y, float r, float angle1, float angle2);
void PSarcn(float x, float y, float r, float angle1, float angle2);
void PSarct(float x1, float y1, float x2, float y2, float r);
void PSflushgraphics(void);
void PSrectclip(float x, float y, float w, float h);
void PSrectfill(float x, float y, float w, float h);
void PSrectstroke(float x, float y, float w, float h);
void PSfill(void);
void PSeofill(void);
void PSstroke(void);
void PSstrokepath(void);
void PSinitclip(void);
void PSclip(void);
void PSeoclip(void);
void PSclippath(void);
void PSlineto(float x, float y);
void PSrlineto(float x, float y);
void PScurveto(float x1, float y1, float x2, float y2, float x3, float y3);
void PSrcurveto(float x1, float y1, float x2, float y2, float x3, float y3);
void PScurrentpoint(float *x, float *y);
void PSsetlinecap(int linecap);
void PSsetlinejoin(int linejoin);
void PSsetlinewidth(float width);
void PSsetgray(float gray);
void PSsetrgbcolor(float r, float g, float b);
void PSsetcmykcolor(float c, float m, float y, float k);
void PSsetalpha(float a);
void PStranslate(float x, float y);
void PSrotate(float angle);
void PSscale(float x, float y);
void PSconcat(const float m[]);
void PSsethalftonephase(int x, int y);
void PSnewpath(void);
void PSclosepath(void);
void PScomposite(float x, float y, float w, float h, int gstateNum, float dx, float dy, int op);
void PScompositerect(float x, float y, float w, float h, int op);
void PSshow(const char *s);
void PSashow(float w, float h, const char *s);

#endif /* ps_h */
