// =================================================================================================
//
//	Starling Framework
//	Copyright Gamua GmbH. All Rights Reserved.
//
//	This program is free software. You can redistribute and/or modify it
//	in accordance with the terms of the accompanying license agreement.
//
// =================================================================================================

package starling.extensions.textures
{
    import flash.display.BitmapData
    import flash.display3D.Context3DTextureFormat;
    import flash.geom.Matrix;
    import flash.geom.Rectangle;
    import flash.utils.Dictionary;

    import starling.textures.Texture;
    import starling.textures.TextureAtlas;
    import starling.utils.Color;
    import starling.utils.Pool;

    /** The BitmapTextureAtlas class allows for creating a texture atlas with bitmaps dynamically at runtime.
     *
     *  <p>This is useful if you need to generate bitmaps at runtime as it allows for taking advantage of Flash's
     *  native drawing API, without the overhead of requiring multiple textures and draw calls per object.</p>
     *
     *  <p>Here is an example using a dynamic texture atlas:</p>
     *
     *  <listing>
     *  var dynamicAtlas:DynamicTextureAtlas = new DynamicTextureAtlas(512, 512);
     *
     *  var nativeSprite:flash.display.Sprite = new flash.display.Sprite();
     *  nativeSprite.graphics.beginFill(0xff);
     *  nativeSprite.graphics.drawRect(0, 0, 50, 50);
     *  nativeSprite.graphics.endFill();
     *
     *  var bitmapData:BitmapData = new BitmapData(50, 50);
     *  bitmapData.draw(nativeSprite);
     *  dynamicAtlas.addBitmapData("myRedRectangle", bitmapData);
     *  dynamicAtlas.update();
     *
     *  var myRedRectangle:Image = new Image(dynamicAtlas.getTexture("myRedRectangle");
     *  addChild(myRedRectangle);
     *  </listing>
     *
     *  @see starling.extensions.textures.MaxRectPacker
     */
    public class DynamicTextureAtlas extends TextureAtlas
    {
        private var _packer:MaxRectPacker;
        private var _atlasData:BitmapData;
        private var _needsUpload:Boolean;

        // helpers

        private static const sMatrix:Matrix = new Matrix();
        private static const sBitmaps:Vector.<BitmapData> = new <BitmapData>[];
        private static const sBitmapNames:Vector.<String> = new <String>[];
        private static const sRejectedBitmaps:Vector.<String> = new <String>[];
        private static const sRectanglesIn:Vector.<Rectangle> = new <Rectangle>[];
        private static const sRectanglesOut:Vector.<Rectangle> = new <Rectangle>[];

        /** Creates a dynamic texture atlas of a certain size.
         *
         *  @param width   in points; number of pixels depends on scale parameter
         *  @param height  in points; number of pixels depends on scale parameter
         *  @param color   the RGB color the texture will be filled up
         *  @param alpha   the alpha value that will be used for every pixel
         *  @param premultipliedAlpha  the PMA format you will use the texture with. If you will
         *                 use the texture for bitmap data, use "true"; for ATF data, use "false".
         *  @param mipMapping  indicates if mipmaps should be used for this texture. When you upload
         *                 bitmap data, this decides if mipmaps will be created; when you upload ATF
         *                 data, this decides if mipmaps inside the ATF file will be displayed.
         *  @param optimizeForRenderToTexture  indicates if this texture will be used as render target
         *  @param scale   if you omit this parameter, 'Starling.contentScaleFactor' will be used.
         *  @param format  the context3D texture format to use. Pass one of the packed or
         *                 compressed formats to save memory (at the price of reduced image quality).
         *  @param forcePotTexture  indicates if the underlying Stage3D texture should be created
         *                 as the power-of-two based "Texture" class instead of the more memory
         *                 efficient "RectangleTexture".
         */
        public function DynamicTextureAtlas(width:Number, height:Number, color:uint=0x0, alpha:Number=0.0,
                                            premultipliedAlpha:Boolean=true, mipMapping:Boolean=false,
                                            optimizeForRenderToTexture:Boolean=false,
                                            scale:Number=-1, format:String="bgra",
                                            forcePotTexture:Boolean=false)
        {
            var texture:Texture = Texture.empty(width, height, premultipliedAlpha, mipMapping,
                optimizeForRenderToTexture, scale, format);

            super(texture);

            var hasAlpha:Boolean = true;
            if (format == Context3DTextureFormat.BGR_PACKED || format == Context3DTextureFormat.COMPRESSED)
                hasAlpha = false;

            color = Color.argb(uint(alpha * 255), Color.getRed(color), Color.getGreen(color), Color.getBlue(color));
            _atlasData = new BitmapData(texture.nativeWidth, texture.nativeHeight, hasAlpha, color);
            texture.root.onRestore = function():void
            {
                texture.root.uploadBitmapData(_atlasData);
            };

            _packer = new MaxRectPacker(texture.nativeWidth, texture.nativeHeight, true);
            _needsUpload = true;
        }

        /** Uploads any previously added images to the underlying texture if necessary. Call this after bitmaps have
         *  been added to the atlas. */
        public function update():void
        {
            if (_needsUpload)
            {
                _needsUpload = false;
                texture.root.uploadBitmapData(_atlasData);
            }
        }

        /** Adds a named bitmap data region to the atlas.
         *
         *  @param name  the name of the region.
         *  @param bitmapData  the data used to fill the region.
         *  @param method  the heuristic method used to place each BitmapData object.
         *  @param trim  determines if transparent space should be trimmed from the image.
         *  @return  false if there was no room to insert the region of data.
         */
        public function addBitmapData(name:String, bitmapData:BitmapData, method:String="bestShortSideFit",
                                      trim:Boolean=false):Boolean
        {
            var region:Rectangle;
            var trimRect:Rectangle;

            if (trim)
            {
                trimRect = bitmapData.getColorBoundsRect(0xff000000, 0x00000000);
                region = _packer.insert(trimRect.width, trimRect.height, method);
            }
            else
            {
                trimRect = null;
                region = _packer.insert(bitmapData.width, bitmapData.height, method);
            }

            // return false if no space for rectangle was found
            if (!region) return false;

            _needsUpload = true;

            var rotated:Boolean = region.width != (trimRect ? trimRect.width : bitmapData.width);
            addRegion(name, region, trimRect, rotated);

            sMatrix.identity();

            if (trim)
                sMatrix.translate(-trimRect.x, -trimRect.y);

            if (rotated)
            {
                sMatrix.rotate(Math.PI / 2.0);
                sMatrix.translate(region.width, 0);
            }

            sMatrix.translate(region.x, region.y);

            _atlasData.draw(bitmapData, sMatrix);
            return true;
        }

        /** Adds a batch of named BitmapData objects to the atlas.
         *
         *  @param namedBitmapDatas  a dictionary of BitmapData objects.
         *  @param method  the heuristic method used to place each BitmapData object.
         *  @param trim  determines if transparent space should be trimmed from the image.
         *  @return  a vector containing the names of BitmapData objects unsuccessfully inserted.
         */
        public function addBitmapDataBatch(namedBitmapDatas:Dictionary, method:String="bestShortSideFit",
                                           trim:Boolean=false):Vector.<String>
        {
            for (var name:String in namedBitmapDatas)
            {
                var bitmap:BitmapData = namedBitmapDatas[name];
                sBitmaps[sBitmaps.length] = bitmap;
                sBitmapNames[sBitmapNames.length] = name;

                var trimRect:Rectangle;
                if (trim) trimRect = bitmap.getColorBoundsRect(0xff000000, 0x00000000);
                else      trimRect = null;

                if (trimRect)
                    sRectanglesIn[sRectanglesIn.length] = Pool.getRectangle(
                        trimRect.x, trimRect.y, trimRect.width, trimRect.height);
                else
                    sRectanglesIn[sRectanglesIn.length] = Pool.getRectangle(0, 0, bitmap.width, bitmap.height);
            }

            _packer.insertRectangles(sRectanglesIn, method, sRectanglesOut);
            for (var i:int=0, length:int=sRectanglesOut.length; i<length; ++i)
            {
                if (sRectanglesOut[i])
                {
                    _needsUpload = true;

                    var rotated:Boolean = sRectanglesOut[i].width != sRectanglesIn[i].width;
                    addRegion(sBitmapNames[i], sRectanglesOut[i], trim ? sRectanglesIn[i] : null, rotated);

                    sMatrix.identity();

                    if (trim)
                        sMatrix.translate(-sRectanglesIn[i].x, -sRectanglesIn[i].y);

                    if (rotated)
                    {
                        sMatrix.rotate(Math.PI / 2);
                        sMatrix.translate(sRectanglesOut[i].width, 0);
                    }

                    sMatrix.translate(sRectanglesOut[i].x, sRectanglesOut[i].y);

                    _atlasData.draw(sBitmaps[i], sMatrix);
                }
                else
                {
                    sRejectedBitmaps[sRejectedBitmaps.length] = sBitmapNames[i];
                }

                Pool.putRectangle(sRectanglesIn[i]);
            }

            sBitmaps.length = 0;
            sBitmapNames.length = 0;
            sRectanglesIn.length = 0;
            sRectanglesOut.length = 0;

            if (sRejectedBitmaps.length)
            {
                var rejections:Vector.<String> = sRejectedBitmaps.concat();
                sRejectedBitmaps.length = 0;
                return rejections;
            }
            else return null;
        }

        /** Returns currently the used ratio of the texture atlas. */
        public function get occupancy():Number { return _packer.occupancy; }
    }
}
