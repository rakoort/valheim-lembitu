using UnityEngine;
using UnityEngine.EventSystems;
namespace EpicMMOSystem;
// FriendList's header/background move their parent without bounds or persistence.
// This is intentionally not the saved-panel controller; see UPSTREAM.md #62.
public class DragMenu : MonoBehaviour, IDragHandler
{
    public Transform menu;

    public void OnDrag(PointerEventData eventData)
    {
        menu.position += (Vector3)eventData.delta;
    }
}