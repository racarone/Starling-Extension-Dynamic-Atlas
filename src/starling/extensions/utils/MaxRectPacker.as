// =================================================================================================
//
//	Starling Framework
//	Copyright Gamua GmbH. All Rights Reserved.
//
//	This program is free software. You can redistribute and/or modify it
//	in accordance with the terms of the accompanying license agreement.
//
// =================================================================================================

package starling.extensions.utils
{
    import flash.geom.Rectangle;

    import starling.utils.MathUtil;
    import starling.utils.Pool;

    /** The MaxRectPacker class is used to solve the problem of packing a set of 2D rectangles into a larger bin.
     *
     *  <p>The DynamicAtlasTexture class uses this in order to insert regions at runtime in an efficient manner. This
     *  class is based on the work by Jukka Jylänki.</p
     *
     *  <p>See http://clb.demon.fi/projects/more-rectangle-bin-packing and https://github.com/juj/RectangleBinPack
     *  for more information</p>
     *
     *  @see starling.extensions.utils.MaxRectHeuristic
     */
    public class MaxRectPacker
    {
        // private members

        private var _maxWidth:int;
        private var _maxHeight:int;
        private var _allowRotations:Boolean;
        private var _usedRectangles:Vector.<Rectangle>;
        private var _freeRectangles:Vector.<Rectangle>;

        /** Instantiates a MaxRectPacker with a size used to determine the free area available to insertable rectangles.
         *
         *  @param maxWidth        The width of the free region.
         *  @param maxHeight       The height of the free region.
         *  @param allowRotations  True if rectangles are allowed to be rotated to better fit within the free space.
         */
        public function MaxRectPacker(maxWidth:int, maxHeight:int, allowRotations:Boolean=true)
        {
            _maxWidth = maxWidth;
            _maxHeight = maxHeight;
            _allowRotations = allowRotations;
            _usedRectangles = new <Rectangle>[];
            _freeRectangles = new <Rectangle>[];
            _freeRectangles[_freeRectangles.length] = new Rectangle(0, 0, maxWidth, maxHeight);
        }

        /** Inserts a single rectangle into the bin, possibly rotated.
         *
         *  @param width   The width of the rectangle to be inserted.
         *  @param height  The height of the rectangle to be inserted.
         *  @param method  The heuristic method used to place the rectangle.
         *  @return        false if the insertion wasn't successful.
         *
         *  @see starling.extensions.utils.MaxRectHeuristic
         */
        public function insert(width:int, height:int, method:String):Rectangle
        {
            var result:MaxRectResult = MaxRectResult.fromPool();
            var bestNode:Rectangle = null;

            if (method == MaxRectHeuristic.BEST_SHORT_SIDE_FIT)
                findPositionForNewNodeBestShortSideFit(width, height, result);
            else if (method == MaxRectHeuristic.RULE_BOTTOM_LEFT)
                findPositionForNewNodeBottomLeft(width, height, result);
            else if (method == MaxRectHeuristic.RULE_CONTACT_POINT)
                findPositionForNewNodeContactPoint(width, height, result);
            else if (method == MaxRectHeuristic.BEST_LONG_SIDE_FIT)
                findPositionForNewNodeBestLongSideFit(width, height, result);
            else if (method == MaxRectHeuristic.BEST_AREA_FIT)
                findPositionForNewNodeBestAreaFit(width, height, result);
            else
                throw new ArgumentError("Invalid heuristic method: " + method);

            if (result.node.height != 0)
            {
                var numRectanglesToProcess:int = _freeRectangles.length;
                for (var i:int=0; i<numRectanglesToProcess; ++i)
                {
                    if (splitFreeNode(_freeRectangles[i], result.node))
                    {
                        _freeRectangles.removeAt(i);
                        --i;
                        --numRectanglesToProcess;
                    }
                }

                pruneFreeList();
                _usedRectangles[_usedRectangles.length] = result.node.clone();
                bestNode = result.node.clone();
            }

            MaxRectResult.toPool(result);
            return bestNode;
        }

        /** Inserts the given list of rectangles in a batch mode, possibly rotated.
         *
         *  @param rectangles  The list of rectangles to insert.
         *  @param method      The heuristic method used to place the rectangle.
         *  @param out         A vector that will contain the successfully inserted rectangles.
         *  @return            A vector of rectangles successfully inserted.
         *
         *  @see starling.extensions.utils.MaxRectHeuristic
         */
        public function insertRectangles(rectangles:Vector.<Rectangle>, method:String,
                                         out:Vector.<Rectangle>=null):Vector.<Rectangle>
        {
            if (!out) out = new Vector.<Rectangle>(rectangles.length);
            else
            {
                out.length = 0;
                out.length = rectangles.length;
            }

            rectangles = rectangles.concat();

            while (rectangles.length > 0)
            {
                var bestResult:MaxRectResult = MaxRectResult.fromPool(null, int.MAX_VALUE, int.MAX_VALUE);
                var bestRectIndex:int = -1;

                for (var i:int=0; i<rectangles.length; ++i)
                {
                    var result:MaxRectResult = MaxRectResult.fromPool();

                    scoreRect(int(rectangles[i].width), int(rectangles[i].height), method, result);
                    if (result.score1 < bestResult.score1 ||
                        (result.score1 == bestResult.score1 && result.score2 < bestResult.score2))
                    {
                        bestResult.copyFrom(result);
                        bestRectIndex = i;
                    }

                    MaxRectResult.toPool(result);
                }

                if (bestRectIndex == -1)
                    break;

                placeRect(bestResult.node);
                rectangles.removeAt(bestRectIndex);
                out[bestRectIndex] = bestResult.node.clone();
                MaxRectResult.toPool(bestResult);
            }

            return out;
        }

        // rectangle sorting

        private function placeRect(node:Rectangle):void
        {
            var numRectanglesToProcess:int = _freeRectangles.length;
            for (var i:int=0; i<numRectanglesToProcess; ++i)
            {
                if (splitFreeNode(_freeRectangles[i], node))
                {
                    _freeRectangles.removeAt(i);
                    --i;
                    --numRectanglesToProcess;
                }
            }

            pruneFreeList();
            _usedRectangles[_usedRectangles.length] = node.clone();
        }

        private function scoreRect(width:int, height:int, method:String, result:MaxRectResult):void
        {
            if (method == MaxRectHeuristic.BEST_SHORT_SIDE_FIT)
                findPositionForNewNodeBestShortSideFit(width, height, result);
            else if (method == MaxRectHeuristic.RULE_BOTTOM_LEFT)
                findPositionForNewNodeBottomLeft(width, height, result);
            else if (method == MaxRectHeuristic.RULE_CONTACT_POINT)
                findPositionForNewNodeContactPoint(width, height, result);
            else if (method == MaxRectHeuristic.BEST_LONG_SIDE_FIT)
                findPositionForNewNodeBestLongSideFit(width, height, result);
            else if (method == MaxRectHeuristic.BEST_AREA_FIT)
                findPositionForNewNodeBestAreaFit(width, height, result);
            else
                throw new ArgumentError("Invalid heuristic method: " + method);

            // cannot fit the current rectangle
            if (result.node.height == 0)
            {
                result.score1 = int.MAX_VALUE;
                result.score2 = int.MAX_VALUE;
            }
        }

        private function findPositionForNewNodeBottomLeft(width:int, height:int, result:MaxRectResult):void
        {
            var bestNode:Rectangle = Pool.getRectangle();
            var bestX:int = int.MAX_VALUE;
            var bestY:int = int.MAX_VALUE;

            var freeLength:int = _freeRectangles.length;
            for (var i:int=0; i<freeLength; ++i)
            {
                var topSideY:int;

                // try to place the rectangle in upright (non-flipped) orientation
                if (_freeRectangles[i].width >= width && _freeRectangles[i].height >= height)
                {
                    topSideY = int(_freeRectangles[i].y + height);
                    if (topSideY < bestY || (topSideY == bestY && _freeRectangles[i].x < bestX))
                    {
                        bestNode.x = _freeRectangles[i].x;
                        bestNode.y = _freeRectangles[i].y;
                        bestNode.width = width;
                        bestNode.height = height;
                        bestY = topSideY;
                        bestX = int(_freeRectangles[i].x);
                    }
                }

                if (_allowRotations && _freeRectangles[i].width >= height && _freeRectangles[i].height >= width)
                {
                    topSideY = int(_freeRectangles[i].y + width);
                    if (topSideY < bestY || (topSideY == bestY && _freeRectangles[i].x < bestX))
                    {
                        bestNode.x = _freeRectangles[i].x;
                        bestNode.y = _freeRectangles[i].y;
                        bestNode.width = height;
                        bestNode.height = width;
                        bestY = topSideY;
                        bestX = int(_freeRectangles[i].x);
                    }
                }
            }

            Pool.putRectangle(bestNode);
            result.reset(bestNode, bestX, bestY);
        }

        private function findPositionForNewNodeBestShortSideFit(width:int, height:int, result:MaxRectResult):void
        {
            var bestNode:Rectangle = Pool.getRectangle();
            var bestShortSideFit:int = int.MAX_VALUE;
            var bestLongSideFit:int = int.MAX_VALUE;

            var freeLength:int = _freeRectangles.length;
            for (var i:int=0; i<freeLength; ++i)
            {
                var leftoverHoriz:int, leftoverVert:int,
                    shortSideFit:int, longSideFit:int;

                // try to place the rectangle in upright (non-flipped) orientation
                if (_freeRectangles[i].width >= width && _freeRectangles[i].height >= height)
                {
                    leftoverHoriz = Math.abs(int(_freeRectangles[i].width - width));
                    leftoverVert = Math.abs(int(_freeRectangles[i].height - height));
                    shortSideFit = Math.min(leftoverHoriz, leftoverVert);
                    longSideFit = Math.max(leftoverHoriz, leftoverVert);

                    if (shortSideFit < bestShortSideFit || (shortSideFit == bestShortSideFit && longSideFit < bestLongSideFit))
                    {
                        bestNode.x = _freeRectangles[i].x;
                        bestNode.y = _freeRectangles[i].y;
                        bestNode.width = width;
                        bestNode.height = height;
                        bestShortSideFit = shortSideFit;
                        bestLongSideFit = longSideFit;
                    }
                }

                if (_allowRotations && _freeRectangles[i].width >= height && _freeRectangles[i].height >= width)
                {
                    leftoverHoriz = Math.abs(int(_freeRectangles[i].width - height));
                    leftoverVert = Math.abs(int(_freeRectangles[i].height - width));
                    shortSideFit = Math.min(leftoverHoriz, leftoverVert);
                    longSideFit = Math.max(leftoverHoriz, leftoverVert);

                    if (shortSideFit < bestShortSideFit || (shortSideFit == bestShortSideFit && longSideFit < bestLongSideFit))
                    {
                        bestNode.x = _freeRectangles[i].x;
                        bestNode.y = _freeRectangles[i].y;
                        bestNode.width = height;
                        bestNode.height = width;
                        bestShortSideFit = shortSideFit;
                        bestLongSideFit = longSideFit;
                    }
                }
            }

            result.reset(bestNode, bestShortSideFit, bestLongSideFit);
            Pool.putRectangle(bestNode);
        }

        private function findPositionForNewNodeBestLongSideFit(width:int, height:int, result:MaxRectResult):void
        {
            var bestNode:Rectangle = Pool.getRectangle();
            var bestShortSideFit:int = int.MAX_VALUE;
            var bestLongSideFit:int = int.MAX_VALUE;

            var freeLength:int = _freeRectangles.length;

            for (var i:int=0; i<freeLength; ++i)
            {
                var leftoverHoriz:int, leftoverVert:int,
                    shortSideFit:int, longSideFit:int;

                // try to place the rectangle in upright (non-flipped) orientation
                if (_freeRectangles[i].width >= width && _freeRectangles[i].height >= height)
                {
                    leftoverHoriz = Math.abs(int(_freeRectangles[i].width - width));
                    leftoverVert = Math.abs(int(_freeRectangles[i].height - height));
                    shortSideFit = MathUtil.min(leftoverHoriz, leftoverVert);
                    longSideFit = MathUtil.max(leftoverHoriz, leftoverVert);

                    if (longSideFit < bestLongSideFit || (longSideFit == bestLongSideFit && shortSideFit < bestShortSideFit))
                    {
                        bestNode.x = _freeRectangles[i].x;
                        bestNode.y = _freeRectangles[i].y;
                        bestNode.width = width;
                        bestNode.height = height;
                        bestShortSideFit = shortSideFit;
                        bestLongSideFit = longSideFit;
                    }
                }

                if (_allowRotations && _freeRectangles[i].width >= height && _freeRectangles[i].height >= width)
                {
                    leftoverHoriz = Math.abs(int(_freeRectangles[i].width - height));
                    leftoverVert = Math.abs(int(_freeRectangles[i].height - width));
                    shortSideFit = MathUtil.min(leftoverHoriz, leftoverVert);
                    longSideFit = MathUtil.max(leftoverHoriz, leftoverVert);

                    if (longSideFit < bestLongSideFit || (longSideFit == bestLongSideFit && shortSideFit < bestShortSideFit))
                    {
                        bestNode.x = _freeRectangles[i].x;
                        bestNode.y = _freeRectangles[i].y;
                        bestNode.width = height;
                        bestNode.height = width;
                        bestShortSideFit = shortSideFit;
                        bestLongSideFit = longSideFit;
                    }
                }
            }

            result.reset(bestNode, bestShortSideFit, bestLongSideFit);
            Pool.putRectangle(bestNode);
        }

        private function findPositionForNewNodeBestAreaFit(width:int, height:int, result:MaxRectResult):void
        {
            var bestNode:Rectangle = Pool.getRectangle();
            var bestAreaFit:int = int.MAX_VALUE;
            var bestShortSideFit:int = int.MAX_VALUE;

            for (var i:int=0, freeLength:int=_freeRectangles.length; i<freeLength; ++i)
            {
                var leftoverHoriz:int, leftoverVert:int, shortSideFit:int;
                var areaFit:int = int(_freeRectangles[i].width) * int(_freeRectangles[i].height) - width * height;

                // try to place the rectangle in upright (non-flipped) orientation
                if (_freeRectangles[i].width >= width && _freeRectangles[i].height >= height)
                {
                    leftoverHoriz = Math.abs(int(_freeRectangles[i].width) - width);
                    leftoverVert = Math.abs(int(_freeRectangles[i].height) - height);
                    shortSideFit = MathUtil.min(leftoverHoriz, leftoverVert);

                    if (areaFit < bestAreaFit || (areaFit == bestAreaFit && shortSideFit < bestShortSideFit))
                    {
                        bestNode.x = _freeRectangles[i].x;
                        bestNode.y = _freeRectangles[i].y;
                        bestNode.width = width;
                        bestNode.height = height;
                        bestShortSideFit = shortSideFit;
                        bestAreaFit = areaFit;
                    }
                }

                if (_allowRotations && _freeRectangles[i].width >= height && _freeRectangles[i].height >= width)
                {
                    leftoverHoriz = Math.abs(int(_freeRectangles[i].width) - height);
                    leftoverVert = Math.abs(int(_freeRectangles[i].height) - width);
                    shortSideFit = MathUtil.min(leftoverHoriz, leftoverVert);

                    if (areaFit < bestAreaFit || (areaFit == bestAreaFit && shortSideFit < bestShortSideFit))
                    {
                        bestNode.x = _freeRectangles[i].x;
                        bestNode.y = _freeRectangles[i].y;
                        bestNode.width = height;
                        bestNode.height = width;
                        bestShortSideFit = shortSideFit;
                        bestAreaFit = areaFit;
                    }
                }
            }

            result.reset(bestNode, bestAreaFit, bestShortSideFit);
            Pool.putRectangle(bestNode);
        }

        /** Returns 0 if the two intervals i1 and i2 are disjoint, or the length of their overlap otherwise. **/
        private static function commonIntervalLength(i1start:int, i1end:int, i2start:int, i2end:int):int
        {
            if (i1end < i2start || i2end < i1start)
                return 0;
            else
                return MathUtil.min(i1end, i2end) - MathUtil.max(i1start, i2start);
        }

        private function calcContactPointScore(x:int, y:int, width:int, height:int):int
        {
            var score:int = 0;

            if (x == 0 || x + width == _maxWidth)
                score += height;
            if (y == 0 || y + height == _maxHeight)
                score += width;

            for (var i:int=0, usedLength:int=_usedRectangles.length; i<usedLength; ++i)
            {
                if (_usedRectangles[i].x == x + width || _usedRectangles[i].x + _usedRectangles[i].width == x)
                {
                    score += commonIntervalLength(
                        int(_usedRectangles[i].y),
                        int(_usedRectangles[i].y) + int(_usedRectangles[i].height),
                        y,
                        y + height);
                }

                if (_usedRectangles[i].y == y + height || _usedRectangles[i].y + _usedRectangles[i].height == y)
                {
                    score += commonIntervalLength(
                        int(_usedRectangles[i].x),
                        int(_usedRectangles[i].x) + int(_usedRectangles[i].width),
                        x,
                        x + width);
                }
            }

            return score;
        }

        private function findPositionForNewNodeContactPoint(width:int, height:int, result:MaxRectResult):void
        {
            var bestNode:Rectangle = Pool.getRectangle();
            var bestContactScore:int = -1;

            for (var i:int=0, freeLength:int=_freeRectangles.length; i<freeLength; ++i)
            {
                var score:int;

                // try to place the rectangle in upright (non-flipped) orientation
                if (_freeRectangles[i].width >= width && _freeRectangles[i].height >= height)
                {
                    score = calcContactPointScore(int(_freeRectangles[i].x), int(_freeRectangles[i].y), width, height);
                    if (score > bestContactScore)
                    {
                        bestNode.x = int(_freeRectangles[i].x);
                        bestNode.y = int(_freeRectangles[i].y);
                        bestNode.width = width;
                        bestNode.height = height;
                        bestContactScore = score;
                    }
                }

                if (_allowRotations && _freeRectangles[i].width >= height && _freeRectangles[i].height >= width)
                {
                    score = calcContactPointScore(int(_freeRectangles[i].x), int(_freeRectangles[i].y), height, width);
                    if (score > bestContactScore)
                    {
                        bestNode.x = int(_freeRectangles[i].x);
                        bestNode.y = int(_freeRectangles[i].y);
                        bestNode.width = height;
                        bestNode.height = width;
                        bestContactScore = score;
                    }
                }
            }

            result.reset(bestNode, bestContactScore);
            Pool.putRectangle(bestNode);
        }

        private function splitFreeNode(freeNode:Rectangle, usedNode:Rectangle):Boolean
        {
            var newNode:Rectangle = new Rectangle();

            // test with SAT if the rectangles even intersect
            if (usedNode.x >= freeNode.x + freeNode.width || usedNode.x + usedNode.width <= freeNode.x ||
                usedNode.y >= freeNode.y + freeNode.height || usedNode.y + usedNode.height <= freeNode.y)
                return false;

            if (usedNode.x < freeNode.x + freeNode.width && usedNode.x + usedNode.width > freeNode.x)
            {
                // new node at the top side of the used node
                if (usedNode.y > freeNode.y && usedNode.y < freeNode.y + freeNode.height)
                {
                    newNode = freeNode.clone();
                    newNode.height = usedNode.y - newNode.y;
                    _freeRectangles[_freeRectangles.length] = newNode;
                }

                // new node at the bottom side of the used node
                if (usedNode.y + usedNode.height < freeNode.y + freeNode.height)
                {
                    newNode = freeNode.clone();
                    newNode.y = usedNode.y + usedNode.height;
                    newNode.height = freeNode.y + freeNode.height - (usedNode.y + usedNode.height);
                    _freeRectangles[_freeRectangles.length] = newNode;
                }
            }

            if (usedNode.y < freeNode.y + freeNode.height && usedNode.y + usedNode.height > freeNode.y)
            {
                // new node at the left side of the used node
                if (usedNode.x > freeNode.x && usedNode.x < freeNode.x + freeNode.width)
                {
                    newNode = freeNode.clone();
                    newNode.width = usedNode.x - newNode.x;
                    _freeRectangles[_freeRectangles.length] = newNode;
                }

                // new node at the right side of the used node
                if (usedNode.x + usedNode.width < freeNode.x + freeNode.width)
                {
                    newNode = freeNode.clone();
                    newNode.x = usedNode.x + usedNode.width;
                    newNode.width = freeNode.x + freeNode.width - (usedNode.x + usedNode.width);
                    _freeRectangles[_freeRectangles.length] = newNode;
                }
            }

            return true;
        }

        private function pruneFreeList():void
        {
            for (var i:int=0; i<_freeRectangles.length; ++i)
            {
                for (var j:int=i+1; j<_freeRectangles.length; ++j)
                {
                    if (_freeRectangles[j].containsRect(_freeRectangles[i]))
                    {
                        _freeRectangles.removeAt(i);
                        --i;
                        break;
                    }

                    if (_freeRectangles[i].containsRect(_freeRectangles[j]))
                    {
                        _freeRectangles.removeAt(j);
                        --j;
                    }
                }
            }
        }

        // properties

        /** Computes the ratio of used surface area. */
        public function get occupancy():Number
        {
            var usedSurfaceArea:uint = 0;
            for (var i:int=0, usedLength:int=_usedRectangles.length; i<usedLength; ++i)
                usedSurfaceArea += uint(_usedRectangles[i].width) * uint(_usedRectangles[i].height);

            return usedSurfaceArea / (_maxWidth * _maxHeight);
        }

        /** The maximum width of the bin area. */
        public function get maxWidth():Number { return _maxWidth; }
        public function set maxWidth(value:Number):void { _maxWidth = value; }

        /** The maximum height of the bin area. */
        public function get maxHeight():Number { return _maxHeight; }
        public function set maxHeight(value:Number):void { _maxHeight = value; }

        /** Determines if rectangles are allowed to be rotated upon placement. */
        public function get allowRotations():Boolean { return _allowRotations; }
        public function set allowRotations(value:Boolean):void { _allowRotations = value; }
    }
}

import flash.geom.Rectangle;

class MaxRectResult
{
    public var node:Rectangle;
    public var score1:int;
    public var score2:int;

    private static var sEventPool:Vector.<MaxRectResult> = new <MaxRectResult>[];

    public function MaxRectResult()
    {
        node = new Rectangle();
        score1 = 0;
        score2 = 0;
    }

    public function reset(node:Rectangle=null, score1:int=0, score2:int=0):MaxRectResult
    {
        if (node) this.node.copyFrom(node);
        else      this.node.setEmpty();

        this.score1 = score1;
        this.score2 = score2;

        return this;
    }

    public function copyFrom(other:MaxRectResult):void
    {
        node.copyFrom(other.node);
        score1 = other.score1;
        score2 = other.score2;
    }

    // pooling

    public static function fromPool(node:Rectangle=null, score1:int=0, score2:int=0):MaxRectResult
    {
        if (sEventPool.length) return sEventPool.pop().reset(node, score1, score2);
        else return new MaxRectResult();
    }

    public static function toPool(event:MaxRectResult):void
    {
        sEventPool[sEventPool.length] = event; // avoiding 'push'
    }
}
