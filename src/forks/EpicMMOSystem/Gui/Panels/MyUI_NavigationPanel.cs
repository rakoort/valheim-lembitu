using API;
using EpicMMOSystem.MonoScripts;
using UnityEngine;
using UnityEngine.UI;


namespace EpicMMOSystem;

public partial class MyUI
{
    internal static GameObject navigationPanel;
    private static Transform buttonLevelSystem;
    private static Transform buttonFriendsList;
    // Upstream's quest, professions and guild buttons are gone with the integrations behind them:
    // KG Marketplace is deprecated and pre-1.0, Professions is not in the stack, and Guilds would
    // be a second membership authority (ADR-0008). The prefab still carries the buttons; nothing
    // activates them, so they stay hidden.
    private static void InitNavigationPanel()
    {
        navigationPanel = UI.transform.Find("Canvas/NavigatePanel").gameObject;
        buttonLevelSystem = navigationPanel.transform.Find("Buttons/ButtonLevelSystem");
        buttonLevelSystem.GetComponent<Button>().onClick.AddListener(ClickButtonLevelSystem);
        DragWindowCntrl.ApplyDragWindowCntrl(navigationPanel);
        //DragControl.Apply

        buttonFriendsList = navigationPanel.transform.Find("Buttons/ButtonFriends");
        buttonFriendsList.GetComponent<Button>().onClick.AddListener(ClickButtonFriendsList);

        // No integration panels: see above.
    }

    private static void ClickButtonLevelSystem()
    {
        if (!levelSystemPanel.activeSelf) UpdateParameterPanel();
        levelSystemPanel.SetActive(!levelSystemPanel.activeSelf);
    }

    private static void ClickButtonFriendsList()
    {
        if (!friendsListPanel.activeSelf) updateList();
        friendsListPanel.SetActive(!friendsListPanel.activeSelf);
    }
    

    private static void ShowNavigationPanel()
    {
        var point = LevelSystem.Instance.getFreePoints();
        buttonLevelSystem.GetChild(0).gameObject.SetActive(point > 0);
        buttonFriendsList.GetChild(0).gameObject.SetActive(hasInvite());
    }


    private static void CloseAllUI()
    {
            navigationPanel.SetActive(false);
            InventoryGui.instance.Hide();
        

        // you can add more as needed (e.g. any other mod panels you know about)
    }


}