using UnityEngine;
using UnityEngine.EventSystems;

namespace EpicMMOSystem.MonoScripts;

public class DragWindowCntrl : MonoBehaviour, IBeginDragHandler, IDragHandler, IEndDragHandler
{

    public static void ApplyDragWindowCntrl(GameObject go)
    {
        go.AddComponent<DragWindowCntrl>();
    }

    private RectTransform _window;

    //delta drag
    private Vector2 _delta;

    private void Awake()
    {
        _window = (RectTransform)transform;
    }

    private void Start()
    {
        //EpicMMOSystem.MLLogger.LogInfo("start");
        RestoreWindow(_window.gameObject);
    }
    internal static void RestoreWindow(GameObject go, bool checkfor0 = true)
    {

        var rectTransform = go.GetComponent<RectTransform>();
        // EpicMMOSystem.MLLogger.LogInfo("Restore Window " + go.name + " " + rectTransform.anchoredPosition);

        if (checkfor0) { 
            switch (go.name)
            {
                case "NavigatePanel":
                    if (EpicMMOSystem.LevelNavPosition.Value != new Vector2(0, 0))
                        rectTransform.anchoredPosition = EpicMMOSystem.LevelNavPosition.Value;
                    break;
                case "PointPanel":
                    if (EpicMMOSystem.LevelPointPosition.Value != new Vector2(0, 0))
                        rectTransform.anchoredPosition = EpicMMOSystem.LevelPointPosition.Value;
                    break;
            }
        }else
        {
            rectTransform.anchoredPosition = go.name switch
            {
                "NavigatePanel" => EpicMMOSystem.LevelNavPosition.Value,
                "PointPanel" => EpicMMOSystem.LevelPointPosition.Value,
                _ => rectTransform.anchoredPosition,
            };
        }
    }

    public void OnBeginDrag(PointerEventData eventData)
    {
        _delta = Input.mousePosition - _window.position;
    }


    public void OnDrag(PointerEventData eventData)
    {
        Vector2 newPos = (Vector2)Input.mousePosition - _delta;
        Vector3 lossyScale = transform.root.lossyScale;
        Rect rect = _window.rect;
        Vector2 currentTransform = new(rect.width * lossyScale.x,
            rect.height * lossyScale.y);
        Vector2 currOffsetMin, currOffsetMax;
        Vector2 pivot = _window.pivot;
        currOffsetMin.x = newPos.x - pivot.x * currentTransform.x;
        currOffsetMin.y = newPos.y - pivot.y * currentTransform.y;
        currOffsetMax.x = newPos.x + (1 - pivot.x) * currentTransform.x;
        currOffsetMax.y = newPos.y + (1 - pivot.y) * currentTransform.y;
        if (currOffsetMin.x < 0)
            newPos.x = _window.pivot.x * currentTransform.x;
        else if (currOffsetMax.x > Screen.width) newPos.x = Screen.width - (1 - _window.pivot.x) * currentTransform.x;
        if (currOffsetMin.y < 0)
            newPos.y = _window.pivot.y * currentTransform.y;
        else if (currOffsetMax.y > Screen.height) newPos.y = Screen.height - (1 - _window.pivot.y) * currentTransform.y;
        _window.position = newPos;
    }

    
    public void OnEndDrag(PointerEventData eventData)
    {
   
        var go = _window.gameObject;
        var rectTransform = go.GetComponent<RectTransform>();
        //EpicMMOSystem.MLLogger.LogInfo("Vector3 " + go.name + " Changed to: " + rectTransform.anchoredPosition);
        switch (go.name)
        {
            case "NavigatePanel":
                EpicMMOSystem.LevelNavPosition.Value = rectTransform.anchoredPosition;
                break;
            case "PointPanel":
                EpicMMOSystem.LevelPointPosition.Value = rectTransform.anchoredPosition;
                break;


        }   

    }
       

}