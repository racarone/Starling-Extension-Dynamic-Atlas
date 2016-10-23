// =================================================================================================
//
//	Starling Framework
//	Copyright Gamua GmbH. All Rights Reserved.
//
//	This program is free software. You can redistribute and/or modify it
//	in accordance with the terms of the accompanying license agreement.
//
// =================================================================================================

package
{
    import flash.display.BitmapData;

    import starling.core.Starling;
    import starling.display.Image;
    import starling.display.Sprite;
    import starling.events.EnterFrameEvent;
    import starling.events.Event;
    import starling.events.KeyboardEvent;
    import starling.extensions.textures.DynamicTextureAtlas;
    import starling.extensions.textures.MaxRectHeuristic;

    public class Demo extends Sprite
    {
        private var _dynamicAtlases:Vector.<DynamicTextureAtlas>;
        private var _dynamicAtlasIndex:int;
        private var _elipseImages:Vector.<Image>;

        private static const MAX_ATLASES:int = 4;

        public function Demo()
        {
            _elipseImages = new <Image>[];
            _dynamicAtlasIndex = 0;
            _dynamicAtlases = new <DynamicTextureAtlas>[];
            for (var i:int=0; i<MAX_ATLASES; ++i)
                _dynamicAtlases[i] = new DynamicTextureAtlas(1024, 1024);

            addEventListener(Event.ENTER_FRAME, onEnterFrame);
        }

        private function onEnterFrame(e:EnterFrameEvent):void
        {
            for each (var elipseImage:Image in _elipseImages)
                elipseImage.rotation += 0.01;

            if (Starling.frameID % 4 == 0)
                generateBitmapElipse();
        }

        private function generateBitmapElipse():void
        {
            if (_dynamicAtlasIndex >= MAX_ATLASES) return;

            var width:Number  = Math.random()*118 + 10;
            var height:Number = Math.random()*118 + 10;

            var nativeSprite:flash.display.Sprite = new flash.display.Sprite();
            nativeSprite.graphics.lineStyle(1, Math.random() * 0xffffff, 1, true);
            nativeSprite.graphics.drawEllipse(2, 2, width-4, height-4);

            var elipseData:BitmapData = new BitmapData(Math.ceil(width), Math.ceil(height), true, 0x0);
            elipseData.draw(nativeSprite);

            var elipseName:String = "elipse" + _elipseImages.length;
            if (_dynamicAtlases[_dynamicAtlasIndex].addBitmapData(elipseName, elipseData))
            {
                var elipse:Image = new Image(_dynamicAtlases[_dynamicAtlasIndex].getTexture(elipseName));
                elipse.x = Math.random() * stage.stageWidth;
                elipse.y = Math.random() * stage.stageHeight;
                addChild(elipse);
                _elipseImages.push(elipse);

                _dynamicAtlases[_dynamicAtlasIndex].update();
            }
            else
            {
                _dynamicAtlasIndex++;
            }
        }
    }
}
