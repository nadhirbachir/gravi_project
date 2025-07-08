using System;
using System.Collections.Generic;
using System.Data;
using System.Data.Common;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace gravi_infrastructure.Data.Interfaces
{
    public interface IDbConnectionFactory
    {
        DbConnection CreateConnection();
    }
}
