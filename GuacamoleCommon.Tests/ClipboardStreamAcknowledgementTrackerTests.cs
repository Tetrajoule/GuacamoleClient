using GuacamoleClient.Common;
using NUnit.Framework;
using System.Text.Json;

namespace GuacamoleCommon.Tests;

public class ClipboardStreamAcknowledgementTrackerTests
{
    [Test]
    public void Acknowledge_CompletesOnlyAfterEveryClipboardBlobIsAccepted()
    {
        var tracker = new ClipboardStreamAcknowledgementTracker(expectedAcknowledgements: 3);

        Assert.Multiple(() =>
        {
            Assert.That(tracker.Acknowledge(statusCode: 0), Is.EqualTo(ClipboardStreamAcknowledgementProgress.Pending));
            Assert.That(tracker.Acknowledge(statusCode: 0), Is.EqualTo(ClipboardStreamAcknowledgementProgress.Pending));
            Assert.That(tracker.Acknowledge(statusCode: 0), Is.EqualTo(ClipboardStreamAcknowledgementProgress.Completed));
        });
    }

    [Test]
    public void Acknowledge_FailurePreventsClipboardPasteCompletion()
    {
        var tracker = new ClipboardStreamAcknowledgementTracker(expectedAcknowledgements: 2);

        Assert.Multiple(() =>
        {
            Assert.That(tracker.Acknowledge(statusCode: 0), Is.EqualTo(ClipboardStreamAcknowledgementProgress.Pending));
            Assert.That(tracker.Acknowledge(statusCode: 0x0100), Is.EqualTo(ClipboardStreamAcknowledgementProgress.Failed));
            Assert.That(tracker.Acknowledge(statusCode: 0), Is.EqualTo(ClipboardStreamAcknowledgementProgress.Failed));
        });
    }

    [Test]
    public void Acknowledge_DuplicateAcknowledgementDoesNotReopenCompletedTransfer()
    {
        var tracker = new ClipboardStreamAcknowledgementTracker(expectedAcknowledgements: 1);

        Assert.Multiple(() =>
        {
            Assert.That(tracker.Acknowledge(statusCode: 0), Is.EqualTo(ClipboardStreamAcknowledgementProgress.Completed));
            Assert.That(tracker.Acknowledge(statusCode: 0), Is.EqualTo(ClipboardStreamAcknowledgementProgress.Completed));
        });
    }

    [Test]
    public void SerializeForJavaScript_PreservesUnicodeAndEscapesScriptSyntax()
    {
        const string text = "line 1\r\nline 2: \"quoted\" \\ path; </script> 東京 🖥️ 😀";

        string serialized = ClipboardTextBridgeEncoding.SerializeForJavaScript(text);
        string decoded = JsonSerializer.Deserialize<string>(serialized)!;

        Assert.That(decoded, Is.EqualTo(text));
    }

    [Test]
    public void Constructor_RequiresAtLeastOneBlobAcknowledgement()
    {
        Assert.Throws<ArgumentOutOfRangeException>(() => new ClipboardStreamAcknowledgementTracker(0));
    }
}
