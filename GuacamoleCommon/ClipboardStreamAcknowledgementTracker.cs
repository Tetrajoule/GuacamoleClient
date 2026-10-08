using System;
using System.Text.Json;

namespace GuacamoleClient.Common;

internal enum ClipboardStreamAcknowledgementProgress
{
    Pending,
    Completed,
    Failed
}

internal sealed class ClipboardStreamAcknowledgementTracker
{
    private readonly int _expectedAcknowledgements;
    private int _receivedAcknowledgements;
    private ClipboardStreamAcknowledgementProgress? _terminalProgress;

    public ClipboardStreamAcknowledgementTracker(int expectedAcknowledgements)
    {
        if (expectedAcknowledgements <= 0)
            throw new ArgumentOutOfRangeException(nameof(expectedAcknowledgements));

        _expectedAcknowledgements = expectedAcknowledgements;
    }

    public ClipboardStreamAcknowledgementProgress Acknowledge(int statusCode)
    {
        if (_terminalProgress.HasValue)
            return _terminalProgress.Value;

        if (statusCode != 0)
        {
            _terminalProgress = ClipboardStreamAcknowledgementProgress.Failed;
            return _terminalProgress.Value;
        }

        _receivedAcknowledgements++;
        if (_receivedAcknowledgements > _expectedAcknowledgements)
        {
            _terminalProgress = ClipboardStreamAcknowledgementProgress.Failed;
            return _terminalProgress.Value;
        }

        if (_receivedAcknowledgements == _expectedAcknowledgements)
        {
            _terminalProgress = ClipboardStreamAcknowledgementProgress.Completed;
            return _terminalProgress.Value;
        }

        return ClipboardStreamAcknowledgementProgress.Pending;
    }
}

internal static class ClipboardTextBridgeEncoding
{
    public static string SerializeForJavaScript(string text)
        => JsonSerializer.Serialize(text);
}
