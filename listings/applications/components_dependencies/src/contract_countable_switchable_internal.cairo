// ANCHOR: contract
#[starknet::contract]
mod CountableContract {
    use components_dependencies::countable_internal_dep_switch::countable_component;
    use components::switchable::switchable_component;

    component!(path: countable_component, storage: counter, event: CountableEvent);
    component!(path: switchable_component, storage: switch, event: SwitchableEvent);

    #[abi(embed_v0)]
    impl CountableImpl = countable_component::Countable<ContractState>;
    #[abi(embed_v0)]
    impl SwitchableImpl = switchable_component::Switchable<ContractState>;
    impl SwitchableInternalImpl = switchable_component::SwitchableInternalImpl<ContractState>;

    #[storage]
    struct Storage {
        #[substorage(v0)]
        counter: countable_component::Storage,
        #[substorage(v0)]
        switch: switchable_component::Storage
    }

    #[constructor]
    fn constructor(ref self: ContractState) {
        self.switch._off();
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        CountableEvent: countable_component::Event,
        SwitchableEvent: switchable_component::Event,
    }
}
// ANCHOR_END: contract

#[cfg(test)]
mod tests {
    use super::CountableContract;
    use components::countable::{ICountable, ICountableDispatcher, ICountableDispatcherTrait};
    use components::switchable::{ISwitchable, ISwitchableDispatcher, ISwitchableDispatcherTrait};

    use core::starknet::storage::StorageMemberAccessTrait;
    use starknet::deploy_syscall;

    fn deploy() -> (ICountableDispatcher, ISwitchableDispatcher) {
        let (contract_address, _) = deploy_syscall(
            CountableContract::TEST_CLASS_HASH.try_into().unwrap(), 0, array![].span(), false
        )
            .unwrap();

        (ICountableDispatcher { contract_address }, ISwitchableDispatcher { contract_address },)
    }

    #[test]
    #[available_gas(2000000)]
    fn test_init() {
        let (mut counter, mut switch) = deploy();

        assert(counter.get() == 0, 'Counter != 0');
        assert(switch.is_on() == false, 'Switch != false');
    }

    #[test]
    #[available_gas(2000000)]
    fn test_increment_switch_off() {
        let (mut counter, mut switch) = deploy();

        counter.increment();
        assert(counter.get() == 0, 'Counter incremented');
        assert(switch.is_on() == false, 'Switch != false');
    }

    #[test]
    #[available_gas(2000000)]
    fn test_increment_switch_on() {
        let (mut counter, mut switch) = deploy();

        switch.switch();
        assert(switch.is_on() == true, 'Switch != true');

        counter.increment();
        assert(counter.get() == 1, 'Counter did not increment');

        // The counter turned the switch off.
        assert(switch.is_on() == false, 'Switch != false');
    }

    #[test]
    #[available_gas(3000000)]
    fn test_increment_multiple_switches() {
        let (mut counter, mut switch) = deploy();

        switch.switch();

        counter.increment();
        counter.increment(); // off
        counter.increment(); // off
        assert(counter.get() == 1, 'Counter did not increment');

        switch.switch();
        counter.increment();
        switch.switch();
        counter.increment();
        counter.increment();
        assert(counter.get() == 3, 'Counter did not increment');
    }
}
