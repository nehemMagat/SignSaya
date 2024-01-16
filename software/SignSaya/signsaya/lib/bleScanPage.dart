import 'dart:async';

import 'package:flutter/material.dart';
import 'package:bluetooth_low_energy/bluetooth_low_energy.dart';

class _ScannerViewState extends State<ScannerView> {
  late final ValueNotifier<BluetoothLowEnergyState> state;
  late final ValueNotifier<bool> discovering;
  late final ValueNotifier<List<DiscoveredEventArgs>> discoveredEventArgs;
  late final StreamSubscription stateChangedSubscription;
  late final StreamSubscription discoveredSubscription;

  @override
  void initState() {
    super.initState();
    state = ValueNotifier(BluetoothLowEnergyState.unknown);
    discovering = ValueNotifier(false);
    discoveredEventArgs = ValueNotifier([]);
    stateChangedSubscription = CentralManager.instance.stateChanged.listen(
      (eventArgs) {
        state.value = eventArgs.state;
      },
    );
    discoveredSubscription = CentralManager.instance.discovered.listen(
      (eventArgs) {
        final items = discoveredEventArgs.value;
        final i = items.indexWhere(
          (item) => item.peripheral == eventArgs.peripheral,
        );
        if (i < 0) {
          discoveredEventArgs.value = [...items, eventArgs];
        } else {
          items[i] = eventArgs;
          discoveredEventArgs.value = [...items];
        }
      },
    );
    _initialize();
  }

  void _initialize() async {
    state.value = await CentralManager.instance.getState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: buildAppBar(context),
      body: buildBody(context),
    );
  }

  PreferredSizeWidget buildAppBar(BuildContext context) {
    return AppBar(
      title: const Text('Scanner'),
      actions: [
        ValueListenableBuilder(
          valueListenable: state,
          builder: (context, state, child) {
            return ValueListenableBuilder(
              valueListenable: discovering,
              builder: (context, discovering, child) {
                return TextButton(
                  onPressed: state == BluetoothLowEnergyState.poweredOn
                      ? () async {
                          if (discovering) {
                            await stopDiscovery();
                          } else {
                            await startDiscovery();
                          }
                        }
                      : null,
                  child: Text(
                    discovering ? 'END' : 'BEGIN',
                  ),
                );
              },
            );
          },
        ),
      ],
    );
  }

  Future<void> startDiscovery() async {
    discoveredEventArgs.value = [];
    await CentralManager.instance.startDiscovery();
    discovering.value = true;
  }

  Future<void> stopDiscovery() async {
    await CentralManager.instance.stopDiscovery();
    discovering.value = false;
  }

  Widget buildBody(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: discoveredEventArgs,
      builder: (context, discoveredEventArgs, child) {
        // final items = discoveredEventArgs;
        final items = discoveredEventArgs
            .where((eventArgs) => eventArgs.advertisement.name != null)
            .toList();
        return ListView.separated(
          itemBuilder: (context, i) {
            final theme = Theme.of(context);
            final item = items[i];
            final uuid = item.peripheral.uuid;
            final rssi = item.rssi;
            final advertisement = item.advertisement;
            final name = advertisement.name;
            return ListTile(
              onTap: () async {
                final discovering = this.discovering.value;
                if (discovering) {
                  await stopDiscovery();
                }
                if (!mounted) {
                  throw UnimplementedError();
                }
                await Navigator.of(context).pushNamed(
                  'peripheral',
                  arguments: item,
                );
                if (discovering) {
                  await startDiscovery();
                }
              },
              onLongPress: () async {
                await showModalBottomSheet(
                  context: context,
                  builder: (context) {
                    return BottomSheet(
                      onClosing: () {},
                      clipBehavior: Clip.antiAlias,
                      builder: (context) {
                        final manufacturerSpecificData =
                            advertisement.manufacturerSpecificData;
                        return ListView.separated(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16.0,
                            vertical: 40.0,
                          ),
                          itemBuilder: (context, i) {
                            const idWidth = 80.0;
                            if (i == 0) {
                              return const Row(
                                children: [
                                  SizedBox(
                                    width: idWidth,
                                    child: Text('ID'),
                                  ),
                                  Expanded(
                                    child: Text('DATA'),
                                  ),
                                ],
                              );
                            } else {
                              final id =
                                  '0x${manufacturerSpecificData!.id.toRadixString(16).padLeft(4, '0')}';
                              //final value =
                             //     hex.encode(manufacturerSpecificData.data);
                              return Row(
                                children: [
                                  SizedBox(
                                    width: idWidth,
                                    child: Text(id),
                                  ),
                                  //Expanded(
                                    //child: Text(value),
                                  //),
                                ],
                              );
                            }
                          },
                          separatorBuilder: (context, i) {
                            return const Divider();
                          },
                          itemCount: manufacturerSpecificData == null ? 1 : 2,
                        );
                      },
                    );
                  },
                );
              },
              title: Text(name ?? 'N/A'),
              subtitle: Text(
                '$uuid',
                style: theme.textTheme.bodySmall,
                softWrap: false,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  //RssiWidget(rssi),
                  Text('$rssi'),
                ],
              ),
            );
          },
          separatorBuilder: (context, i) {
            return const Divider(
              height: 0.0,
            );
          },
          itemCount: items.length,
        );
      },
    );
  }

  @override
  void dispose() {
    super.dispose();
    stateChangedSubscription.cancel();
    discoveredSubscription.cancel();
    state.dispose();
    discovering.dispose();
    discoveredEventArgs.dispose();
  }
}

class ScannerView extends StatefulWidget {
  const ScannerView({super.key});

  @override
  State<ScannerView> createState() => _ScannerViewState();
}