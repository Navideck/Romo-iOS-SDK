#import "RGLBufferVC.h"
#import "RGLBufferView.h"

#pragma mark - Constants --

// Uniform index.
enum
{
    UNIFORM_Y,
    UNIFORM_UV,
    NUM_UNIFORMS
};
GLint uniforms[NUM_UNIFORMS];

// Attribute index.
enum
{
    ATTRIB_VERTEX,
    ATTRIB_TEXCOORD,
    NUM_ATTRIBUTES
};

static GLfloat vertexCoordinates[] = {
    -1.0f, -1.0f,
    1.0f, -1.0f,
    -1.0f,  1.0f,
    1.0f,  1.0f,
};

#pragma mark -
#pragma mark - GLBufferViewController (Private) --

@interface RGLBufferVC () 
{
    CGRect _frame;
    
    size_t _textureWidth;
    size_t _textureHeight;
    
    EAGLContext *_context;
    
    GLuint _program;
    
    GLuint _positionVBO;
    GLuint _texcoordVBO;
    
    GLuint _lumaTexture;
    GLuint _chromaTexture;
    
    RGLBufferView *_glView;
}

- (void)cleanUpTextures;

- (void)setupBuffers;

- (void)setupGL;
- (void)tearDownGL;

- (BOOL)loadShaders;
- (BOOL)compileShader:(GLuint *)shader type:(GLenum)type file:(NSString *)file;
- (BOOL)linkProgram:(GLuint)prog;

@end

#pragma mark -
#pragma mark - Implementation (GLBufferViewController) --

@implementation RGLBufferVC

#pragma mark - Initialization --

- (id)initWithFrame:(CGRect)frame
{
    if (self = [super init])
    {
        _frame = frame;
    }
    
    return self;
}

#pragma mark - Methods --

- (void)drawPlanes:(void **)planes width:(size_t)width height:(size_t)height
{
    [EAGLContext setCurrentContext:_context];
    
    if (height != _textureWidth || width != _textureHeight) {
        _textureWidth= height;
        _textureHeight = width;
        
        [self setupBuffers];
    }
    
    [self cleanUpTextures];
    
    glClearColor(0.5f, 0.5f, 0.5f, 1.0f);
    glClear(GL_COLOR_BUFFER_BIT);
    
    // Y-plane
    glActiveTexture(GL_TEXTURE0);
	glGenTextures(1, &_lumaTexture);
    glBindTexture(GL_TEXTURE_2D, _lumaTexture);
    
	glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
	glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE); 
    
	glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
	glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST); 
    
	glTexImage2D(GL_TEXTURE_2D, 0, GL_RED_EXT, width, height, 0, GL_RED_EXT, GL_UNSIGNED_BYTE, planes[0]);
    
    glUniform1i(uniforms[UNIFORM_Y], 0);
    
    // UV-plane
    glActiveTexture(GL_TEXTURE1);
	glGenTextures(1, &_chromaTexture);
	glBindTexture(GL_TEXTURE_2D, _chromaTexture);
    
	glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
	glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE); 
    
	glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
	glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST); 
    
	glTexImage2D(GL_TEXTURE_2D, 0, GL_RG_EXT, width / 2, height / 2, 0, GL_RG_EXT, GL_UNSIGNED_BYTE, planes[1]);
    
    glUniform1i(uniforms[UNIFORM_UV], 1);
    
    glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
    int error = glGetError();
    if (error) {
        DDLogError(@"\tglDrawArrays(%d, %d, %d); error = %d (%d,%d,%d)",GL_TRIANGLE_STRIP,0,4,error,GL_INVALID_ENUM,GL_INVALID_VALUE,GL_INVALID_OPERATION);
    }
    [_glView presentFramebuffer];
}

#pragma mark - Methods (Private) --

- (void)loadView
{
    _glView = [[RGLBufferView alloc] initWithFrame:_frame];
    self.view = _glView;
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    _context = [_glView context];
    
    [self setupGL];
}

- (void)viewDidDisappear:(BOOL)animated
{
    [super viewDidDisappear:animated];
    
    [self tearDownGL];
    
    if ([EAGLContext currentContext] == _context) {
        [EAGLContext setCurrentContext:nil];
    }
}

- (void)cleanUpTextures
{
    if (_lumaTexture) {
        glDeleteTextures(1, &_lumaTexture);
        _lumaTexture = 0;
    }
    
    if (_chromaTexture) {
        glDeleteTextures(1, &_chromaTexture);
        _chromaTexture = 0;
    }
}

- (void)setupBuffers
{
    glGenBuffers(1, &_positionVBO);
    glBindBuffer(GL_ARRAY_BUFFER, _positionVBO);
    glBufferData(GL_ARRAY_BUFFER, sizeof(vertexCoordinates), vertexCoordinates, GL_STATIC_DRAW);
    
    glEnableVertexAttribArray(ATTRIB_VERTEX);
    glVertexAttribPointer(ATTRIB_VERTEX, 2, GL_FLOAT, GL_FALSE, 0, 0);
    
    CGFloat frameRatio = _frame.size.height / _frame.size.width;    
    CGFloat textureRatio = ((CGFloat) _textureHeight) / _textureWidth;
    
    if (textureRatio == frameRatio) {
        GLfloat centeredCoordinates[] = {
            1.0f, 0.0f,
            1.0f, 1.0f,
            0.0f, 0.0f,
            0.0f, 1.0f
        };
        
        glGenBuffers(1, &_texcoordVBO);
        glBindBuffer(GL_ARRAY_BUFFER, _texcoordVBO);
        glBufferData(GL_ARRAY_BUFFER, sizeof(centeredCoordinates), centeredCoordinates, GL_STATIC_DRAW);
    } else if (textureRatio < frameRatio) {
        float shiftX = (_textureWidth * _frame.size.height - _frame.size.width * _textureHeight) / (2 * _frame.size.height);
        
        float normX;
        
        if (_textureWidth > shiftX)
            normX = shiftX / _textureWidth;
        else
            normX = _textureWidth / shiftX;
        
        GLfloat centeredCoordinates[] = {
            1.0f + normX, 0.0f,
            1.0f + normX, 1.0f,
            -normX, 0.0f,
            -normX, 1.0f
        };
        
        glGenBuffers(1, &_texcoordVBO);
        glBindBuffer(GL_ARRAY_BUFFER, _texcoordVBO);
        glBufferData(GL_ARRAY_BUFFER, sizeof(centeredCoordinates), centeredCoordinates, GL_STATIC_DRAW);
    } else {
        float shiftY = (_textureHeight * _frame.size.width - _frame.size.height * _textureWidth) / (2 * _frame.size.width);
        
        float normY;
        
        if (_textureWidth > shiftY)
            normY = shiftY / _textureHeight;
        else
            normY = _textureHeight / shiftY;
        
        GLfloat centeredCoordinates[] = {
            1.0f, -normY,
            1.0f, 1.0f + normY,
            0.0f, -normY,
            0.0f, 1.0f + normY
        };
        
        glGenBuffers(1, &_texcoordVBO);
        glBindBuffer(GL_ARRAY_BUFFER, _texcoordVBO);
        glBufferData(GL_ARRAY_BUFFER, sizeof(centeredCoordinates), centeredCoordinates, GL_STATIC_DRAW);
    }
    
    glEnableVertexAttribArray(ATTRIB_TEXCOORD);
    glVertexAttribPointer(ATTRIB_TEXCOORD, 2, GL_FLOAT, GL_FALSE, 0, 0); 
}

- (void)setupGL
{
    [EAGLContext setCurrentContext:_context];
    
    [self loadShaders];
    
    glUseProgram(_program);
    
    glUniform1i(uniforms[UNIFORM_Y], 0);
    glUniform1i(uniforms[UNIFORM_UV], 1);
}

- (void)tearDownGL
{
    [EAGLContext setCurrentContext:_context];
    
    glDeleteBuffers(1, &_positionVBO);
    glDeleteBuffers(1, &_texcoordVBO);
    
    // temporary fix(?) to cause setupBuffers to be called when needed
    _textureWidth= -1;
    _textureHeight = -1;
    
    if (_program)  {
        glDeleteProgram(_program);
        _program = 0;
    }
}

#pragma mark -
#pragma mark - OpenGLES 2 Shader Compilation --

- (BOOL)loadShaders
{
    GLuint vertShader, fragShader;
    NSString *vertShaderPathname, *fragShaderPathname;
    
    // Create shader program.
    _program = glCreateProgram();
    
    // Create and compile vertex shader.
    vertShaderPathname = [[NSBundle mainBundle] pathForResource:@"Shader" ofType:@"vsh"];
    if (![self compileShader:&vertShader type:GL_VERTEX_SHADER file:vertShaderPathname]) {
        NSLog(@"Failed to compile vertex shader");
        return NO;
    }

    // Create and compile fragment shader.
    fragShaderPathname = [[NSBundle mainBundle] pathForResource:@"Shader" ofType:@"fsh"];
    if (![self compileShader:&fragShader type:GL_FRAGMENT_SHADER file:fragShaderPathname]) {
        NSLog(@"Failed to compile fragment shader");
        return NO;
    }
    
    // Attach vertex shader to program.
    glAttachShader(_program, vertShader);
    
    // Attach fragment shader to program.
    glAttachShader(_program, fragShader);
    
    // Bind attribute locations.
    // This needs to be done prior to linking.
    glBindAttribLocation(_program, ATTRIB_VERTEX, "position");
    glBindAttribLocation(_program, ATTRIB_TEXCOORD, "texCoord");
    
    // Link program.
    if (![self linkProgram:_program]) {
        NSLog(@"Failed to link program: %d", _program);
        
        if (vertShader) {
            glDeleteShader(vertShader);
            vertShader = 0;
        }
        if (fragShader) {
            glDeleteShader(fragShader);
            fragShader = 0;
        }
        if (_program) {
            glDeleteProgram(_program);
            _program = 0;
        }
        
        return NO;
    }
    
    // Get uniform locations.
    uniforms[UNIFORM_Y] = glGetUniformLocation(_program, "SamplerY");
    uniforms[UNIFORM_UV] = glGetUniformLocation(_program, "SamplerUV");
    
    // Release vertex and fragment shaders.
    if (vertShader) {
        glDetachShader(_program, vertShader);
        glDeleteShader(vertShader);
    }
    if (fragShader) {
        glDetachShader(_program, fragShader);
        glDeleteShader(fragShader);
    }
    
    return YES;
}

- (BOOL)compileShader:(GLuint *)shader type:(GLenum)type file:(NSString *)file
{
    GLint status;
    const GLchar *source;
    
    source = (GLchar *)[[NSString stringWithContentsOfFile:file encoding:NSUTF8StringEncoding error:nil] UTF8String];
    if (!source) {
        NSLog(@"Failed to load vertex shader");
        return NO;
    }
    
    *shader = glCreateShader(type);
    glShaderSource(*shader, 1, &source, NULL);
    glCompileShader(*shader);
    
#if defined(DEBUG)
    GLint logLength;
    glGetShaderiv(*shader, GL_INFO_LOG_LENGTH, &logLength);
    if (logLength > 0) {
        GLchar *log = (GLchar *)malloc(logLength);
        glGetShaderInfoLog(*shader, logLength, &logLength, log);
        NSLog(@"Shader compile log:\n%s", log);
        free(log);
    }
#endif
    
    glGetShaderiv(*shader, GL_COMPILE_STATUS, &status);
    if (status == 0) {
        glDeleteShader(*shader);
        return NO;
    }
    
    return YES;
}

- (BOOL)linkProgram:(GLuint)prog
{
    GLint status;
    glLinkProgram(prog);
    
#if defined(DEBUG)
    GLint logLength;
    glGetProgramiv(prog, GL_INFO_LOG_LENGTH, &logLength);
    if (logLength > 0) {
        GLchar *log = (GLchar *)malloc(logLength);
        glGetProgramInfoLog(prog, logLength, &logLength, log);
        NSLog(@"Program link log:\n%s", log);
        free(log);
    }
#endif
    
    glGetProgramiv(prog, GL_LINK_STATUS, &status);
    if (status == 0) {
        return NO;
    }
    
    return YES;
}

@end
