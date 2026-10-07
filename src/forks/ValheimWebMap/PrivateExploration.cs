using System;
using System.Collections.Generic;

namespace ValheimWebMap
{
    /// <summary>Hidden movement joins the public exploration only after its peer leaves.</summary>
    internal sealed class PrivateExploration
    {
        private readonly ExploredMask _mask;
        private readonly Dictionary<long, Dictionary<long, Point>> _pending = new Dictionary<long, Dictionary<long, Point>>();
        private readonly HashSet<long> _online = new HashSet<long>();
        private readonly List<long> _departed = new List<long>();
        private struct Point { public float X, Z, Radius; }

        public PrivateExploration(ExploredMask mask) { _mask = mask; }
        public void BeginSample() { _online.Clear(); }
        public void Online(long peer) { _online.Add(peer); }
        public void Record(long peer, float x, float z, float radius)
        {
            Dictionary<long, Point> points;
            if (!_pending.TryGetValue(peer, out points))
                _pending.Add(peer, points = new Dictionary<long, Point>());
            int cx = (int)Math.Floor(x / _mask.CellSize), cz = (int)Math.Floor(z / _mask.CellSize);
            long cell = ((long)cx << 32) ^ (uint)cz;
            points[cell] = new Point { X = x, Z = z, Radius = radius };
        }
        public void EndSample()
        {
            _departed.Clear();
            foreach (var peer in _pending)
            {
                if (_online.Contains(peer.Key)) continue;
                foreach (Point point in peer.Value.Values) _mask.Reveal(point.X, point.Z, point.Radius);
                _departed.Add(peer.Key);
            }
            foreach (long peer in _departed) _pending.Remove(peer);
        }
    }
}
