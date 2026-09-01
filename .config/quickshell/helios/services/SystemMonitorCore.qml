import QtQuick

QtObject {
    id: root

    property var state: ({
        status: "stopped", ready: false,
        cpu: ({ usage_percent: 0, per_core: [], frequency_mhz: 0 }),
        memory: ({ usage_percent: 0, used_gb: 0, total_gb: 0 }),
        disk: ({ read_mb: 0, write_mb: 0 }),
        network: ({ sent_mb: 0, received_mb: 0 }), gpu: null, processes: [],
        networkRate: ({ sentKBs: 0, receivedKBs: 0 }),
        networkSentHistory: [], networkReceivedHistory: [], processAction: null
    })

    function setStatus(status) { root.state = Object.assign({}, root.state, { status: status }); }

    function ingest(line) {
        let data;
        try { data = JSON.parse(line); } catch (error) { return false; }
        if (!data.cpu || !data.memory || !data.disk || !data.network || !data.network_rate || !data.network_history)
            return false;
        root.state = {
            status: "live", ready: true,
            cpu: data.cpu, memory: data.memory, disk: data.disk, network: data.network,
            gpu: data.gpu, processes: data.processes || [],
            networkRate: { sentKBs: data.network_rate.sent_kbs, receivedKBs: data.network_rate.received_kbs },
            networkSentHistory: data.network_history.sent_kbs || [],
            networkReceivedHistory: data.network_history.received_kbs || [],
            processAction: root.state.processAction
        };
        return true;
    }

    function completeProcessAction(result) {
        root.state = Object.assign({}, root.state, { processAction: result });
    }
}
