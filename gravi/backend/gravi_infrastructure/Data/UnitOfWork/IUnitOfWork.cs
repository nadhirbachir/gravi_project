﻿using System;
using System.Collections.Generic;
using System.Data;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace gravi_infrastructure.Data.UnitOfWork
{
    public interface IUnitOfWork
    {
        IDbConnection Connection { get; }
        IDbTransaction? Transaction { get; }
        void BeginTransaction();
        void Commit();
        void RollBack();
        void Dispose();
    }
}
