import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

export default buildModule("Contract", (m) => {
    const Contract = m.contract("IDO");

    return { Contract };
});
