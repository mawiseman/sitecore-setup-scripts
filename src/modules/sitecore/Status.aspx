<%@ Page Language="C#" AutoEventWireup="true" %>

<%@ Import Namespace="System.IO" %>
<%@ Import Namespace="Sitecore.Configuration" %>
<%@ Import Namespace="Sitecore.Diagnostics" %>
<script runat="server">

    #region Methods 

    protected override void OnInitComplete(EventArgs e)
    {
        this.Server.ScriptTimeout = 10 * 60 * 60; // 10 hours should be enough
        var installedTemp = this.Server.MapPath(Path.Combine(Settings.TempFolderPath, "sim.status"));
        var message = GetMessage(installedTemp);

        Log.Info(@"[SIM] Status.aspx: " + message, this);
        this.Response.Write(message);
    }

    private static string GetMessage(string installedTemp)
    {
        if (File.Exists(installedTemp))
        {
            var message = File.ReadAllText(installedTemp);
            File.Delete(installedTemp);
            return message;
        }
        else
        {
            return @"Pending: no information";
        }
    }

    #endregion

</script>
